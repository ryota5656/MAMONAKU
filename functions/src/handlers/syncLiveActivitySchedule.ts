import { onRequest } from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import { auth, errorMessage, serverTimestamp } from "../firebase.js";
import { cancelScheduledTasks, scheduleRotationTasks } from "../rotationTasks.js";
import { liveActivityDeviceDoc, userDeviceDoc } from "../store.js";
import { RotationPayload } from "../types.js";

interface SyncRequestBody {
  deviceId: string;
  fcmToken: string;
  liveActivityToken: string;
  apnsTopic: string;
  rotations?: RotationPayload[];
  firebaseUid?: string;
  idToken?: string;
}

/**
 * 旧クライアント（ver1.x）向けの互換エンドポイント。端末のプッシュ宛先を登録する。
 *
 * 現行クライアントは Firestore の `liveActivityCommands/rebuild` を使い、ここは呼ばない。
 * 旧クライアントが端末で計算した `rotations` を送ってきた場合は、そのまま切り替えを予約する。
 */
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

  const idToken = bearerToken(req.headers.authorization) ?? body.idToken;
  if (!idToken) {
    res.status(401).json({ error: "missing Firebase ID token" });
    return;
  }

  let firebaseUid: string;
  try {
    firebaseUid = await verifyIdToken(idToken, body.firebaseUid);
  } catch (error) {
    res.status(401).json({ error: "invalid Firebase ID token", errorMessage: errorMessage(error) });
    return;
  }

  try {
    const target = {
      fcmToken: body.fcmToken ?? "",
      liveActivityToken: body.liveActivityToken,
      apnsTopic: body.apnsTopic,
    };
    await liveActivityDeviceDoc(body.deviceId).set(
      { firebaseUid, ...target, updatedAt: serverTimestamp() },
      { merge: true }
    );
    await userDeviceDoc(firebaseUid, body.deviceId).set(
      { ...target, updatedAt: serverTimestamp() },
      { merge: true }
    );

    if (body.rotations && body.rotations.length > 0) {
      await cancelScheduledTasks(body.deviceId);
      const scheduledTaskNames = await scheduleRotationTasks(body.deviceId, body.rotations);
      await liveActivityDeviceDoc(body.deviceId).set(
        { rotations: body.rotations, scheduledTaskNames, updatedAt: serverTimestamp() },
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

function bearerToken(header: string | undefined): string | undefined {
  const prefix = "Bearer ";
  return header?.startsWith(prefix) ? header.slice(prefix.length) : undefined;
}

/** ID トークンを検証して uid を返す。`expectedUid` があれば一致も確認する。 */
async function verifyIdToken(idToken: string, expectedUid?: string): Promise<string> {
  const decoded = await auth.verifyIdToken(idToken);
  if (expectedUid && decoded.uid !== expectedUid) {
    throw new Error("firebase uid mismatch");
  }
  return decoded.uid;
}
