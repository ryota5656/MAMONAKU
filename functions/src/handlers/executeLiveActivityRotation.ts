import { onRequest } from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import { TASK_SECRET, clampVisibleSlots } from "../config.js";
import { errorMessage } from "../firebase.js";
import { pushEnd, pushSchedule } from "../liveActivityPush.js";
import { ExecuteRotationRequestBody } from "../rotationTasks.js";
import { buildTaskItems, currentWindow } from "../schedule.js";
import { hasPushTokens, liveActivityDeviceDoc, loadTodayEntries } from "../store.js";
import { PushTarget, RotationPayload } from "../types.js";

/**
 * Cloud Tasks から予定の開始時刻に呼ばれ、Live Activity を次の表示へ切り替える。
 *
 * 予約後に予定が変わっていても正しく表示できるよう、最新の schedules から表示を計算し直す。
 * uid の無い旧クライアントの端末だけは、登録時に受け取った `rotations` をそのまま使う。
 */
export const executeLiveActivityRotation = onRequest({ invoker: "public" }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  if (req.headers["x-task-secret"] !== TASK_SECRET) {
    res.status(403).json({ error: "forbidden" });
    return;
  }

  const body = req.body as ExecuteRotationRequestBody;
  if (!body.deviceId || body.rotationIndex === undefined) {
    res.status(400).json({ error: "deviceId and rotationIndex are required" });
    return;
  }

  try {
    const doc = await liveActivityDeviceDoc(body.deviceId).get();
    if (!doc.exists) {
      res.status(404).json({ error: "device not found" });
      return;
    }

    const data = doc.data()!;
    const target: PushTarget = {
      fcmToken: data.fcmToken as string,
      liveActivityToken: data.liveActivityToken as string,
      apnsTopic: data.apnsTopic as string,
    };
    if (!hasPushTokens(target)) {
      res.status(400).json({ error: "missing push tokens" });
      return;
    }

    const maxVisibleSlots = clampVisibleSlots(data.maxVisibleSlots);
    const firebaseUid = data.firebaseUid as string | undefined;
    if (firebaseUid) {
      const now = new Date();
      const entries = await loadTodayEntries(firebaseUid, now);
      const { window } = currentWindow(entries, now, maxVisibleSlots);
      await pushSchedule(target, buildTaskItems(window, now));
    } else {
      const rotation = ((data.rotations ?? []) as RotationPayload[])[body.rotationIndex];
      if (!rotation) {
        res.status(404).json({ error: "rotation not found" });
        return;
      }
      if (rotation.shouldEndActivity) {
        await pushEnd(target);
      } else {
        await pushSchedule(target, rotation.schedule.slice(0, maxVisibleSlots));
      }
    }

    logger.info("Live Activity rotation executed", {
      deviceId: body.deviceId,
      rotationIndex: body.rotationIndex,
      switchAt: new Date().toISOString(),
    });
    res.status(200).json({ ok: true });
  } catch (error) {
    logger.error("executeLiveActivityRotation failed", { error: errorMessage(error) });
    res.status(500).json({ error: "execution failed", errorMessage: errorMessage(error) });
  }
});
