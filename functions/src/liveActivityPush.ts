import { messaging } from "./firebase.js";
import { buildContentState, primaryStaleDateUnix, refreshScheduleForPush } from "./schedule.js";
import { toUnixSeconds } from "./time.js";
import { PushTarget, TaskItemPayload } from "./types.js";

/** 表示する予定を Live Activity へ送る。予定が無ければ Live Activity を終える。 */
export async function pushSchedule(target: PushTarget, schedule: TaskItemPayload[]): Promise<void> {
  if (schedule.length === 0) {
    await pushEnd(target);
    return;
  }

  const now = new Date();
  const refreshed = refreshScheduleForPush(schedule, now);
  const aps: Record<string, unknown> = {
    timestamp: toUnixSeconds(now),
    event: "update",
    "content-state": buildContentState(refreshed),
  };
  const staleDate = primaryStaleDateUnix(refreshed);
  if (staleDate !== undefined) aps["stale-date"] = staleDate;
  await send(target, aps);
}

/** Live Activity を終える。 */
export async function pushEnd(target: PushTarget): Promise<void> {
  await send(target, { timestamp: toUnixSeconds(new Date()), event: "end" });
}

async function send(target: PushTarget, aps: Record<string, unknown>): Promise<void> {
  await messaging.send({
    token: target.fcmToken,
    apns: {
      liveActivityToken: target.liveActivityToken,
      headers: {
        "apns-push-type": "liveactivity",
        "apns-topic": target.apnsTopic,
        "apns-priority": "10",
      },
      payload: { aps },
    },
  });
}
