/**
 * Live Activity をサーバーから更新する Cloud Functions。
 *
 * 1. 端末が予定を `users/{uid}/schedules` に書き、`liveActivityCommands/rebuild` を書く
 * 2. `onLiveActivityRebuildRequested` が今の表示をプッシュし、以降の切り替えを Cloud Tasks に予約する
 * 3. 予定の開始時刻に `executeLiveActivityRotation` が呼ばれ、次の表示をプッシュする
 */
export { onLiveActivityRebuildRequested } from "./handlers/onLiveActivityRebuildRequested.js";
export { executeLiveActivityRotation } from "./handlers/executeLiveActivityRotation.js";
export { syncLiveActivitySchedule } from "./handlers/syncLiveActivitySchedule.js";
