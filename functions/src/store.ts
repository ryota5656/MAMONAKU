import { DEFAULT_APNS_TOPIC } from "./config.js";
import { db } from "./firebase.js";
import { todayEntries } from "./schedule.js";
import { PushTarget, ScheduleDoc, ScheduledEntry } from "./types.js";

/**
 * Firestore のコレクション。
 *
 * - `users/{uid}/schedules`: 端末から同期された予定
 * - `users/{uid}/devices`: ユーザーの端末と、その端末へのプッシュ宛先
 * - `liveActivityDevices/{deviceId}`: 端末ごとの切り替え予約の状態（旧クライアントが登録した宛先もここにある）
 */
export const userDoc = (uid: string) => db.collection("users").doc(uid);
export const userDeviceDoc = (uid: string, deviceId: string) => userDoc(uid).collection("devices").doc(deviceId);
export const liveActivityDeviceDoc = (deviceId: string) => db.collection("liveActivityDevices").doc(deviceId);

/** ユーザーの当日の予定を開始時刻順に読む。 */
export async function loadTodayEntries(uid: string, now: Date): Promise<ScheduledEntry[]> {
  const snap = await userDoc(uid).collection("schedules").get();
  return todayEntries(
    snap.docs.map((doc) => ({ id: doc.id, data: doc.data() as ScheduleDoc })),
    now
  );
}

export async function loadUserDeviceIds(uid: string): Promise<string[]> {
  const snap = await userDoc(uid).collection("devices").get();
  return snap.docs.map((doc) => doc.id);
}

/** 端末へのプッシュ宛先。`users/{uid}/devices` を優先し、無い項目は `liveActivityDevices` で補う。 */
export async function loadPushTarget(uid: string, deviceId: string): Promise<PushTarget> {
  const [deviceDoc, laDoc] = await Promise.all([
    userDeviceDoc(uid, deviceId).get(),
    liveActivityDeviceDoc(deviceId).get(),
  ]);
  const device = deviceDoc.data() ?? {};
  const legacy = laDoc.data() ?? {};
  return {
    fcmToken: (device.fcmToken as string) || (legacy.fcmToken as string) || "",
    liveActivityToken: (device.liveActivityToken as string) || (legacy.liveActivityToken as string) || "",
    apnsTopic: (device.apnsTopic as string) || (legacy.apnsTopic as string) || DEFAULT_APNS_TOPIC,
  };
}

export function hasPushTokens(target: PushTarget): boolean {
  return Boolean(target.fcmToken && target.liveActivityToken);
}
