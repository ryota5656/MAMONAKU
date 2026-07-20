import * as admin from "firebase-admin";
import { CloudTasksClient } from "@google-cloud/tasks";
import { setGlobalOptions } from "firebase-functions";
import { onRequest } from "firebase-functions/https";
import { onDocumentWritten } from "firebase-functions/firestore";
import * as logger from "firebase-functions/logger";

setGlobalOptions({ maxInstances: 10 });

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const tasksClient = new CloudTasksClient();

const PROJECT_ID = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? "mamonaku-98306";
const TASKS_LOCATION = process.env.TASKS_LOCATION ?? "us-central1";
const TASKS_QUEUE = process.env.TASKS_QUEUE ?? "live-activity-rotations";
const TASK_SECRET = process.env.TASK_SECRET ?? "mamonaku-live-activity-task-secret";

interface TaskItemPayload {
  nextTitle: string;
  nextStartDate?: number;
  nextEndDate?: number;
  countdownStartDate?: number;
  remainingTimeShort: string;
  bufferMinutes?: number;
}

interface RotationPayload {
  switchAtUnix: number;
  schedule: TaskItemPayload[];
  shouldEndActivity: boolean;
  reason?: string;
}

interface SyncRequestBody {
  deviceId: string;
  fcmToken: string;
  liveActivityToken: string;
  apnsTopic: string;
  rotations?: RotationPayload[];
  firebaseUid?: string;
  idToken?: string;
}

interface ExecuteRequestBody {
  deviceId: string;
  rotationIndex: number;
}

interface ScheduleDoc {
  title?: string;
  durationMinutes?: number;
  startMinutes?: number | null;
  dropDate?: admin.firestore.Timestamp | null;
  startDate?: admin.firestore.Timestamp | null;
  endDate?: admin.firestore.Timestamp | null;
  isAllDay?: boolean;
  deleted?: boolean;
  bufferMinutes?: number | null;
}

interface ScheduledEntry {
  id: string;
  title: string;
  startDate: Date;
  endDate: Date;
  bufferMinutes?: number;
}

function queuePath(): string {
  return tasksClient.queuePath(PROJECT_ID, TASKS_LOCATION, TASKS_QUEUE);
}

function executeFunctionUrl(): string {
  return `https://${TASKS_LOCATION}-${PROJECT_ID}.cloudfunctions.net/executeLiveActivityRotation`;
}

function unixToISO(unix: number): string {
  return new Date(unix * 1000).toISOString();
}

function grpcCode(error: unknown): number | undefined {
  return (error as { code?: number }).code;
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

const REFERENCE_DATE_OFFSET_SEC = 978307200;

function toReferenceDateSeconds(date: Date): number {
  return Math.floor(date.getTime() / 1000) - REFERENCE_DATE_OFFSET_SEC;
}

function referenceDateSecondsFromNow(): number {
  return Math.floor(Date.now() / 1000) - REFERENCE_DATE_OFFSET_SEC;
}

function refreshScheduleForPush(schedule: TaskItemPayload[]): TaskItemPayload[] {
  if (schedule.length === 0) return schedule;
  const [primary, ...rest] = schedule;
  const nowRef = referenceDateSecondsFromNow();
  const nextStart = primary.nextStartDate;
  return [
    {
      ...primary,
      countdownStartDate:
        nextStart !== undefined && nextStart <= nowRef ? nextStart - 1 : nowRef,
    },
    ...rest,
  ];
}

function buildContentState(schedule: TaskItemPayload[]): Record<string, unknown> {
  return {
    schedule: schedule.map((item) => {
      const mapped: Record<string, unknown> = {
        nextTitle: item.nextTitle,
        remainingTimeShort: item.remainingTimeShort,
      };
      if (item.nextStartDate !== undefined) mapped.nextStartDate = item.nextStartDate;
      if (item.nextEndDate !== undefined) mapped.nextEndDate = item.nextEndDate;
      if (item.countdownStartDate !== undefined) mapped.countdownStartDate = item.countdownStartDate;
      if (item.bufferMinutes !== undefined) mapped.bufferMinutes = item.bufferMinutes;
      return mapped;
    }),
  };
}

function primaryStaleDateUnix(schedule: TaskItemPayload[]): number | undefined {
  const primary = schedule[0];
  if (primary?.nextStartDate === undefined) return undefined;
  return Math.floor(primary.nextStartDate + REFERENCE_DATE_OFFSET_SEC);
}

function extractBearerToken(
  headers: Record<string, string | string[] | undefined>,
  body: SyncRequestBody
): string | undefined {
  const authHeader = headers.authorization ?? headers.Authorization;
  if (typeof authHeader === "string" && authHeader.startsWith("Bearer ")) {
    return authHeader.slice("Bearer ".length);
  }
  return body.idToken;
}

async function verifyFirebaseIdToken(idToken: string, expectedUid?: string): Promise<string> {
  const decoded = await admin.auth().verifyIdToken(idToken);
  if (expectedUid && decoded.uid !== expectedUid) {
    throw new Error("firebase uid mismatch");
  }
  return decoded.uid;
}

async function ensureTasksQueue(): Promise<void> {
  const name = queuePath();
  try {
    await tasksClient.getQueue({ name });
    return;
  } catch (error) {
    if (grpcCode(error) !== 5) throw error;
  }

  const parent = tasksClient.locationPath(PROJECT_ID, TASKS_LOCATION);
  try {
    await tasksClient.createQueue({ parent, queue: { name } });
  } catch (error) {
    if (grpcCode(error) === 6) return;
    throw error;
  }
}

async function sendLiveActivityUpdate(params: {
  fcmToken: string;
  liveActivityToken: string;
  apnsTopic: string;
  event: "update" | "end";
  contentState?: Record<string, unknown>;
  staleDateUnix?: number;
}): Promise<void> {
  const timestamp = Math.floor(Date.now() / 1000);
  const aps: Record<string, unknown> = {
    timestamp,
    event: params.event,
  };
  if (params.event === "update" && params.contentState) {
    aps["content-state"] = params.contentState;
    if (params.staleDateUnix !== undefined) {
      aps["stale-date"] = params.staleDateUnix;
    }
  }

  await messaging.send({
    token: params.fcmToken,
    apns: {
      liveActivityToken: params.liveActivityToken,
      headers: {
        "apns-push-type": "liveactivity",
        "apns-topic": params.apnsTopic,
        "apns-priority": "10",
      },
      payload: { aps },
    },
  });
}

async function cancelScheduledTasks(deviceId: string): Promise<void> {
  const doc = await db.collection("liveActivityDevices").doc(deviceId).get();
  const taskNames: string[] = doc.data()?.scheduledTaskNames ?? [];
  await Promise.all(
    taskNames.map(async (name) => {
      try {
        await tasksClient.deleteTask({ name });
      } catch (error) {
        logger.warn("Failed to delete task", { name, error: errorMessage(error) });
      }
    })
  );
}

async function scheduleRotationTasks(
  deviceId: string,
  rotations: RotationPayload[]
): Promise<string[]> {
  await ensureTasksQueue();
  const scheduledTaskNames: string[] = [];
  const parent = queuePath();
  const executeUrl = executeFunctionUrl();

  for (let index = 0; index < rotations.length; index += 1) {
    const rotation = rotations[index];
    const body: ExecuteRequestBody = { deviceId, rotationIndex: index };
    const [task] = await tasksClient.createTask({
      parent,
      task: {
        scheduleTime: { seconds: rotation.switchAtUnix },
        httpRequest: {
          httpMethod: "POST",
          url: executeUrl,
          headers: {
            "Content-Type": "application/json",
            "X-Task-Secret": TASK_SECRET,
          },
          body: Buffer.from(JSON.stringify(body)).toString("base64"),
        },
      },
    });
    if (task.name) scheduledTaskNames.push(task.name);
  }
  return scheduledTaskNames;
}

function startOfDayTokyo(date: Date): Date {
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = fmt.formatToParts(date);
  const y = Number(parts.find((p) => p.type === "year")?.value);
  const m = Number(parts.find((p) => p.type === "month")?.value);
  const d = Number(parts.find((p) => p.type === "day")?.value);
  // Asia/Tokyo is UTC+9 with no DST
  return new Date(Date.UTC(y, m - 1, d, -9, 0, 0));
}

function isSameTokyoDay(a: Date, b: Date): boolean {
  return startOfDayTokyo(a).getTime() === startOfDayTokyo(b).getTime();
}

function shortCountdown(to: Date, from: Date): string {
  const seconds = Math.max(0, Math.floor((to.getTime() - from.getTime()) / 1000));
  if (seconds >= 3600) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}:${String(minutes).padStart(2, "0")}`;
  }
  const minutes = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${minutes}:${String(secs).padStart(2, "0")}`;
}

function stackTimeLabel(startDate: Date, now: Date): string {
  const minutes = Math.max(0, Math.floor((startDate.getTime() - now.getTime()) / 60000));
  if (minutes < 120) return `${minutes}分後`;
  const fmt = new Intl.DateTimeFormat("ja-JP", {
    timeZone: "Asia/Tokyo",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  return fmt.format(startDate);
}

function buildTaskItems(
  window: ScheduledEntry[],
  now: Date
): TaskItemPayload[] {
  return window.map((entry, index) => {
    if (index === 0) {
      return {
        nextTitle: entry.title,
        nextStartDate: toReferenceDateSeconds(entry.startDate),
        nextEndDate: toReferenceDateSeconds(entry.endDate),
        countdownStartDate: toReferenceDateSeconds(now),
        remainingTimeShort: shortCountdown(entry.startDate, now),
        bufferMinutes: entry.bufferMinutes,
      };
    }
    return {
      nextTitle: entry.title,
      nextStartDate: toReferenceDateSeconds(entry.startDate),
      remainingTimeShort: stackTimeLabel(entry.startDate, now),
      bufferMinutes: entry.bufferMinutes,
    };
  });
}

function buildRotations(
  entries: ScheduledEntry[],
  startIndex: number,
  now: Date,
  maxVisibleSlots: number
): RotationPayload[] {
  if (startIndex >= entries.length) return [];
  const rotations: RotationPayload[] = [];

  for (let index = startIndex; index < entries.length; index += 1) {
    const switchAt = entries[index].startDate;
    if (switchAt.getTime() <= now.getTime()) continue;

    const isLast = index === entries.length - 1;
    if (isLast) {
      rotations.push({
        switchAtUnix: Math.floor(switchAt.getTime() / 1000),
        schedule: [],
        shouldEndActivity: true,
        reason: maxVisibleSlots <= 1 ? "free_single_event_started" : "last_event_started",
      });
      continue;
    }

    const nextIndex = index + 1;
    const windowEnd = Math.min(nextIndex + maxVisibleSlots, entries.length);
    const window = entries.slice(nextIndex, windowEnd);
    rotations.push({
      switchAtUnix: Math.floor(switchAt.getTime() / 1000),
      schedule: buildTaskItems(window, switchAt),
      shouldEndActivity: false,
      reason: "next_event_countdown",
    });
  }
  return rotations;
}

async function loadTodayEntries(uid: string, now: Date): Promise<ScheduledEntry[]> {
  const snap = await db.collection("users").doc(uid).collection("schedules").get();
  const today = startOfDayTokyo(now);
  const entries: ScheduledEntry[] = [];

  for (const doc of snap.docs) {
    const data = doc.data() as ScheduleDoc;
    if (data.deleted === true || data.isAllDay === true) continue;
    if (data.startMinutes === null || data.startMinutes === undefined) continue;
    if (!data.dropDate) continue;

    const dropDate = data.dropDate.toDate();
    if (!isSameTokyoDay(dropDate, today)) continue;

    let startDate: Date;
    let endDate: Date;
    if (data.startDate) {
      startDate = data.startDate.toDate();
      endDate = data.endDate
        ? data.endDate.toDate()
        : new Date(startDate.getTime() + (data.durationMinutes ?? 30) * 60_000);
    } else {
      const dayStart = startOfDayTokyo(dropDate);
      startDate = new Date(dayStart.getTime() + data.startMinutes * 60_000);
      const duration = data.durationMinutes ?? 30;
      endDate = new Date(startDate.getTime() + duration * 60_000);
    }
    entries.push({
      id: doc.id,
      title: data.title ?? "予定",
      startDate,
      endDate,
      bufferMinutes: data.bufferMinutes ?? undefined,
    });
  }

  entries.sort((a, b) => a.startDate.getTime() - b.startDate.getTime());
  return entries;
}

function currentWindow(
  entries: ScheduledEntry[],
  now: Date,
  maxVisibleSlots: number
): { startIndex: number; window: ScheduledEntry[] } {
  if (entries.length === 0) return { startIndex: 0, window: [] };
  const currentIndex = entries.findIndex((e) => e.startDate.getTime() > now.getTime());
  const startIndex = currentIndex === -1 ? entries.length : currentIndex;
  if (startIndex >= entries.length) return { startIndex, window: [] };
  return {
    startIndex,
    window: entries.slice(startIndex, startIndex + maxVisibleSlots),
  };
}

async function rebuildLiveActivityForUser(params: {
  uid: string;
  deviceId?: string;
  maxVisibleSlots?: number;
}): Promise<void> {
  const now = new Date();
  const maxVisibleSlots = params.maxVisibleSlots ?? 3;
  const entries = await loadTodayEntries(params.uid, now);
  const { startIndex, window } = currentWindow(entries, now, maxVisibleSlots);
  const schedule = buildTaskItems(window, now);
  const rotations = buildRotations(entries, startIndex, now, maxVisibleSlots);

  const devicesSnap = await db.collection("users").doc(params.uid).collection("devices").get();
  let deviceIds = params.deviceId
    ? [params.deviceId]
    : devicesSnap.docs.map((d) => d.id);

  if (deviceIds.length === 0 && params.deviceId) {
    deviceIds = [params.deviceId];
  }

  for (const deviceId of deviceIds) {
    await cancelScheduledTasks(deviceId);

    const deviceDoc = await db.collection("users").doc(params.uid).collection("devices").doc(deviceId).get();
    const laDoc = await db.collection("liveActivityDevices").doc(deviceId).get();
    const deviceData = deviceDoc.data() ?? {};
    const laData = laDoc.data() ?? {};

    const fcmToken = (deviceData.fcmToken as string) || (laData.fcmToken as string) || "";
    const liveActivityToken =
      (deviceData.liveActivityToken as string) || (laData.liveActivityToken as string) || "";
    const apnsTopic =
      (deviceData.apnsTopic as string) ||
      (laData.apnsTopic as string) ||
      "sairyo.MAMONAKU.push-type.liveactivity";

    let scheduledTaskNames: string[] = [];
    let taskSchedulingError: string | undefined;
    if (rotations.length > 0 && fcmToken) {
      try {
        scheduledTaskNames = await scheduleRotationTasks(deviceId, rotations);
      } catch (error) {
        taskSchedulingError = errorMessage(error);
        logger.error("Cloud Tasks scheduling failed", { deviceId, error: taskSchedulingError });
      }
    }

    await db.collection("liveActivityDevices").doc(deviceId).set(
      {
        firebaseUid: params.uid,
        fcmToken,
        liveActivityToken,
        apnsTopic,
        rotations,
        maxVisibleSlots,
        scheduledTaskNames,
        lastTaskSchedulingError: taskSchedulingError ?? null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (!fcmToken || !liveActivityToken) {
      logger.warn("Skip immediate push: missing tokens", { deviceId });
      continue;
    }

    if (schedule.length === 0) {
      await sendLiveActivityUpdate({
        fcmToken,
        liveActivityToken,
        apnsTopic,
        event: "end",
      });
    } else {
      const refreshed = refreshScheduleForPush(schedule);
      await sendLiveActivityUpdate({
        fcmToken,
        liveActivityToken,
        apnsTopic,
        event: "update",
        contentState: buildContentState(refreshed),
        staleDateUnix: primaryStaleDateUnix(refreshed),
      });
    }

    logger.info("Rebuilt Live Activity schedule", {
      uid: params.uid,
      deviceId,
      entryCount: entries.length,
      visible: schedule.length,
      rotations: rotations.length,
      scheduledTasks: scheduledTaskNames.length,
    });
  }
}

/** クライアントが schedules 反映後に書く rebuild コマンドを監視 */
export const onLiveActivityRebuildRequested = onDocumentWritten(
  "users/{uid}/liveActivityCommands/rebuild",
  async (event) => {
    const uid = event.params.uid as string;
    const after = event.data?.after;
    if (!after?.exists) return;

    const data = after.data() ?? {};
    const deviceId = typeof data.deviceId === "string" ? data.deviceId : undefined;
    const maxVisibleSlots =
      typeof data.maxVisibleSlots === "number" ? data.maxVisibleSlots : 3;

    try {
      await rebuildLiveActivityForUser({ uid, deviceId, maxVisibleSlots });
    } catch (error) {
      logger.error("onLiveActivityRebuildRequested failed", {
        uid,
        error: errorMessage(error),
      });
      throw error;
    }
  }
);

/** 互換用: トークン登録。rotations が来ても schedules 監視フローへ寄せる */
export const syncLiveActivitySchedule = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const body = req.body as SyncRequestBody;
  if (!body.deviceId || !body.liveActivityToken || !body.apnsTopic) {
    res.status(400).json({ error: "deviceId, liveActivityToken and apnsTopic are required" });
    return;
  }

  const idToken = extractBearerToken(req.headers, body);
  if (!idToken) {
    res.status(401).json({ error: "missing Firebase ID token" });
    return;
  }

  let firebaseUid: string;
  try {
    firebaseUid = await verifyFirebaseIdToken(idToken, body.firebaseUid);
  } catch (error) {
    res.status(401).json({
      error: "invalid Firebase ID token",
      errorMessage: errorMessage(error),
    });
    return;
  }

  try {
    await db.collection("liveActivityDevices").doc(body.deviceId).set(
      {
        firebaseUid,
        fcmToken: body.fcmToken ?? "",
        liveActivityToken: body.liveActivityToken,
        apnsTopic: body.apnsTopic,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await db
      .collection("users")
      .doc(firebaseUid)
      .collection("devices")
      .doc(body.deviceId)
      .set(
        {
          fcmToken: body.fcmToken ?? "",
          liveActivityToken: body.liveActivityToken,
          apnsTopic: body.apnsTopic,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    // 旧クライアント互換: rotations 付きなら従来どおり Tasks 登録
    if (body.rotations && body.rotations.length > 0) {
      await cancelScheduledTasks(body.deviceId);
      const scheduledTaskNames = await scheduleRotationTasks(body.deviceId, body.rotations);
      await db.collection("liveActivityDevices").doc(body.deviceId).set(
        {
          rotations: body.rotations,
          scheduledTaskNames,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      res.status(200).json({ ok: true, scheduledTasks: scheduledTaskNames.length, mode: "legacy_rotations" });
      return;
    }

    res.status(200).json({ ok: true, mode: "tokens_only" });
  } catch (error) {
    logger.error("syncLiveActivitySchedule failed", { error: errorMessage(error) });
    res.status(500).json({ error: "sync failed", errorMessage: errorMessage(error) });
  }
});

export const executeLiveActivityRotation = onRequest(
  { invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const taskSecret = req.headers["x-task-secret"];
    if (taskSecret !== TASK_SECRET) {
      res.status(403).json({ error: "forbidden" });
      return;
    }

    const body = req.body as ExecuteRequestBody;
    if (!body.deviceId || body.rotationIndex === undefined) {
      res.status(400).json({ error: "deviceId and rotationIndex are required" });
      return;
    }

    try {
      const doc = await db.collection("liveActivityDevices").doc(body.deviceId).get();
      if (!doc.exists) {
        res.status(404).json({ error: "device not found" });
        return;
      }

      const data = doc.data()!;
      const firebaseUid = data.firebaseUid as string | undefined;
      const fcmToken = data.fcmToken as string;
      const liveActivityToken = data.liveActivityToken as string;
      const apnsTopic = data.apnsTopic as string;
      if (!fcmToken || !liveActivityToken) {
        res.status(400).json({ error: "missing push tokens" });
        return;
      }

      // 最新 schedules から再計算（古い Task でも安全）。表示件数は端末に保存したプランを尊重。
      if (firebaseUid) {
        const now = new Date();
        const entries = await loadTodayEntries(firebaseUid, now);
        const maxVisibleSlots =
          typeof data.maxVisibleSlots === "number" ? data.maxVisibleSlots : 1;
        const { window } = currentWindow(entries, now, maxVisibleSlots);
        if (window.length === 0) {
          await sendLiveActivityUpdate({
            fcmToken,
            liveActivityToken,
            apnsTopic,
            event: "end",
          });
        } else {
          const schedule = refreshScheduleForPush(buildTaskItems(window, now));
          await sendLiveActivityUpdate({
            fcmToken,
            liveActivityToken,
            apnsTopic,
            event: "update",
            contentState: buildContentState(schedule),
            staleDateUnix: primaryStaleDateUnix(schedule),
          });
        }
      } else {
        const rotations = (data.rotations ?? []) as RotationPayload[];
        const rotation = rotations[body.rotationIndex];
        if (!rotation) {
          res.status(404).json({ error: "rotation not found" });
          return;
        }
        if (rotation.shouldEndActivity) {
          await sendLiveActivityUpdate({
            fcmToken,
            liveActivityToken,
            apnsTopic,
            event: "end",
          });
        } else {
          const refreshedSchedule = refreshScheduleForPush(rotation.schedule);
          await sendLiveActivityUpdate({
            fcmToken,
            liveActivityToken,
            apnsTopic,
            event: "update",
            contentState: buildContentState(refreshedSchedule),
            staleDateUnix: primaryStaleDateUnix(refreshedSchedule),
          });
        }
      }

      logger.info("Live Activity rotation executed", {
        deviceId: body.deviceId,
        rotationIndex: body.rotationIndex,
        switchAt: unixToISO(Math.floor(Date.now() / 1000)),
      });
      res.status(200).json({ ok: true });
    } catch (error) {
      logger.error("executeLiveActivityRotation failed", { error: errorMessage(error) });
      res.status(500).json({ error: "execution failed", errorMessage: errorMessage(error) });
    }
  }
);
