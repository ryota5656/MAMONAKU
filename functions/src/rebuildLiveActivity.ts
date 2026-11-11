import * as logger from "firebase-functions/logger";
import { clampVisibleSlots } from "./config.js";
import { errorMessage, serverTimestamp } from "./firebase.js";
import { pushSchedule } from "./liveActivityPush.js";
import { buildRotations, buildTaskItems, currentWindow } from "./schedule.js";
import { cancelScheduledTasks, scheduleRotationTasks } from "./rotationTasks.js";
import { hasPushTokens, liveActivityDeviceDoc, loadPushTarget, loadTodayEntries, loadUserDeviceIds } from "./store.js";

/**
 * ユーザーの当日の予定から Live Activity を組み直す。
 *
 * 端末ごとに、今表示すべき予定を即時プッシュし、以降の切り替えを Cloud Tasks に予約し直す。
 * `deviceId` が無ければ、ユーザーのすべての端末が対象。
 */
export async function rebuildLiveActivityForUser(params: {
  uid: string;
  deviceId?: string;
  maxVisibleSlots?: number;
}): Promise<void> {
  const now = new Date();
  const maxVisibleSlots = clampVisibleSlots(params.maxVisibleSlots);
  const entries = await loadTodayEntries(params.uid, now);
  const { startIndex, window } = currentWindow(entries, now, maxVisibleSlots);
  const schedule = buildTaskItems(window, now);
  const rotations = buildRotations(entries, startIndex, now, maxVisibleSlots);

  const deviceIds = params.deviceId ? [params.deviceId] : await loadUserDeviceIds(params.uid);

  for (const deviceId of deviceIds) {
    await cancelScheduledTasks(deviceId);
    const target = await loadPushTarget(params.uid, deviceId);

    let scheduledTaskNames: string[] = [];
    let taskSchedulingError: string | undefined;
    if (rotations.length > 0 && target.fcmToken) {
      try {
        scheduledTaskNames = await scheduleRotationTasks(deviceId, rotations);
      } catch (error) {
        taskSchedulingError = errorMessage(error);
        logger.error("Cloud Tasks scheduling failed", { deviceId, error: taskSchedulingError });
      }
    }

    await liveActivityDeviceDoc(deviceId).set(
      {
        firebaseUid: params.uid,
        ...target,
        rotations,
        maxVisibleSlots,
        scheduledTaskNames,
        lastTaskSchedulingError: taskSchedulingError ?? null,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );

    if (!hasPushTokens(target)) {
      logger.warn("Skip immediate push: missing tokens", { deviceId });
      continue;
    }

    await pushSchedule(target, schedule);

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
