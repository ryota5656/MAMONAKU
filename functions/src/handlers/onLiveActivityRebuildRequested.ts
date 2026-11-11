import { onDocumentWritten } from "firebase-functions/firestore";
import * as logger from "firebase-functions/logger";
import { errorMessage } from "../firebase.js";
import { rebuildLiveActivityForUser } from "../rebuildLiveActivity.js";
import { liveActivityDeviceDoc } from "../store.js";

/** 端末が schedules を書き終えた後に書く rebuild コマンドを受けて、Live Activity を組み直す。 */
export const onLiveActivityRebuildRequested = onDocumentWritten(
  "users/{uid}/liveActivityCommands/rebuild",
  async (event) => {
    const uid = event.params.uid as string;
    const after = event.data?.after;
    if (!after?.exists) return;

    const data = after.data() ?? {};
    const deviceId = typeof data.deviceId === "string" ? data.deviceId : undefined;
    let maxVisibleSlots = typeof data.maxVisibleSlots === "number" ? data.maxVisibleSlots : undefined;

    // コマンドに無い場合は端末に保存済みの値を使い、それも無ければ無料相当の 1 件。
    if (maxVisibleSlots === undefined && deviceId) {
      const stored = (await liveActivityDeviceDoc(deviceId).get()).data()?.maxVisibleSlots;
      if (typeof stored === "number") maxVisibleSlots = stored;
    }

    try {
      await rebuildLiveActivityForUser({ uid, deviceId, maxVisibleSlots });
    } catch (error) {
      logger.error("onLiveActivityRebuildRequested failed", { uid, error: errorMessage(error) });
      throw error;
    }
  }
);
