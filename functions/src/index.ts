import * as admin from "firebase-admin";
import { CloudTasksClient } from "@google-cloud/tasks";
import { setGlobalOptions } from "firebase-functions";
import { onRequest } from "firebase-functions/https";
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
  rotations: RotationPayload[];
  firebaseUid?: string;
  idToken?: string;
}

interface ExecuteRequestBody {
  deviceId: string;
  rotationIndex: number;
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

function tokenPreview(token: string): string {
  if (!token || token.length <= 16) return token;
  return `${token.slice(0, 8)}…${token.slice(-4)} (${token.length} chars)`;
}

// Cocoa reference date (2001-01-01) offset from Unix epoch in seconds.
const REFERENCE_DATE_OFFSET_SEC = 978307200;

function referenceDateSecondsFromNow(): number {
  return Math.floor(Date.now() / 1000) - REFERENCE_DATE_OFFSET_SEC;
}

/** push 送信直前にプライマリの countdownStartDate を現在時刻へ更新する。 */
function refreshScheduleForPush(schedule: TaskItemPayload[]): TaskItemPayload[] {
  if (schedule.length === 0) return schedule;

  const [primary, ...rest] = schedule;
  const nowRef = referenceDateSecondsFromNow();
  const nextStart = primary.nextStartDate;

  return [
    {
      ...primary,
      countdownStartDate:
        nextStart !== undefined && nextStart <= nowRef
          ? nextStart - 1
          : nowRef,
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
    logger.info("Cloud Tasks queue exists", { queue: TASKS_QUEUE, location: TASKS_LOCATION });
    return;
  } catch (error) {
    if (grpcCode(error) !== 5) throw error;
  }

  const parent = tasksClient.locationPath(PROJECT_ID, TASKS_LOCATION);
  logger.info("Creating Cloud Tasks queue", { queue: TASKS_QUEUE, location: TASKS_LOCATION });
  try {
    await tasksClient.createQueue({
      parent,
      queue: { name },
    });
    logger.info("Cloud Tasks queue created", { queue: TASKS_QUEUE });
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

  logger.info("Sending Live Activity push via FCM", {
    event: params.event,
    fcmToken: tokenPreview(params.fcmToken),
    liveActivityToken: tokenPreview(params.liveActivityToken),
    apnsTopic: params.apnsTopic,
  });

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
    const scheduleTime = { seconds: rotation.switchAtUnix };
    const body: ExecuteRequestBody = { deviceId, rotationIndex: index };

    const [task] = await tasksClient.createTask({
      parent,
      task: {
        scheduleTime,
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

    if (task.name) {
      scheduledTaskNames.push(task.name);
    }
  }

  return scheduledTaskNames;
}

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
    logger.warn("syncLiveActivitySchedule rejected: invalid Firebase ID token", {
      deviceId: body.deviceId,
      error: errorMessage(error),
    });
    res.status(401).json({
      error: "invalid Firebase ID token",
      errorMessage: errorMessage(error),
    });
    return;
  }

  const rotations = body.rotations ?? [];

  logger.info("syncLiveActivitySchedule received", {
    deviceId: body.deviceId,
    firebaseUid,
    fcmToken: tokenPreview(body.fcmToken ?? ""),
    liveActivityToken: tokenPreview(body.liveActivityToken),
    apnsTopic: body.apnsTopic,
    rotationCount: rotations.length,
  });

  try {
    await cancelScheduledTasks(body.deviceId);

    let scheduledTaskNames: string[] = [];
    let taskSchedulingError: string | undefined;

    if (rotations.length > 0 && body.fcmToken) {
      try {
        scheduledTaskNames = await scheduleRotationTasks(body.deviceId, rotations);
      } catch (error) {
        taskSchedulingError = errorMessage(error);
        logger.error("Cloud Tasks scheduling failed (tokens will still be saved)", {
          deviceId: body.deviceId,
          error: taskSchedulingError,
        });
      }
    }

    await db.collection("liveActivityDevices").doc(body.deviceId).set({
      firebaseUid,
      fcmToken: body.fcmToken ?? "",
      liveActivityToken: body.liveActivityToken,
      apnsTopic: body.apnsTopic,
      rotations,
      scheduledTaskNames,
      lastTaskSchedulingError: taskSchedulingError ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await db
      .collection("users")
      .doc(firebaseUid)
      .collection("devices")
      .doc(body.deviceId)
      .set(
        {
          apnsTopic: body.apnsTopic,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    if (taskSchedulingError) {
      res.status(500).json({
        error: "sync failed",
        errorMessage: taskSchedulingError,
        hint: "Cloud Tasks queue or IAM permissions may be missing. Enable cloudtasks.googleapis.com and grant Cloud Tasks Enqueuer to the Functions service account.",
        tokensSaved: true,
        scheduledTasks: scheduledTaskNames.length,
      });
      return;
    }

    logger.info("syncLiveActivitySchedule completed", {
      deviceId: body.deviceId,
      firebaseUid,
      scheduledTasks: scheduledTaskNames.length,
      rotationCount: rotations.length,
    });

    res.status(200).json({
      ok: true,
      scheduledTasks: scheduledTaskNames.length,
    });
  } catch (error) {
    const message = errorMessage(error);
    logger.error("syncLiveActivitySchedule failed", { error: message, stack: error instanceof Error ? error.stack : undefined });
    res.status(500).json({
      error: "sync failed",
      errorMessage: message,
    });
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
    logger.warn("executeLiveActivityRotation rejected: invalid task secret");
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
    const rotations = (data.rotations ?? []) as RotationPayload[];
    const rotation = rotations[body.rotationIndex];
    if (!rotation) {
      res.status(404).json({ error: "rotation not found" });
      return;
    }

    const fcmToken = data.fcmToken as string;
    const liveActivityToken = data.liveActivityToken as string;
    const apnsTopic = data.apnsTopic as string;

    if (!fcmToken || !liveActivityToken) {
      res.status(400).json({ error: "missing push tokens" });
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

    logger.info("Live Activity rotation executed", {
      deviceId: body.deviceId,
      rotationIndex: body.rotationIndex,
      shouldEnd: rotation.shouldEndActivity,
      reason: rotation.reason ?? "unknown",
      switchAt: unixToISO(rotation.switchAtUnix),
      scheduleTitles: rotation.schedule.map((item) => item.nextTitle),
    });

    res.status(200).json({ ok: true });
  } catch (error) {
    logger.error("executeLiveActivityRotation failed", { error: errorMessage(error) });
    res.status(500).json({ error: "execution failed", errorMessage: errorMessage(error) });
  }
});
