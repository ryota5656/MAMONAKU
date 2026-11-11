/** 実行環境ごとの設定値。未設定時の既定値は PROD 相当。 */
export const PROJECT_ID = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? "mamonaku-98306";
export const TASKS_LOCATION = process.env.TASKS_LOCATION ?? "us-central1";
export const TASKS_QUEUE = process.env.TASKS_QUEUE ?? "live-activity-rotations";
/** Cloud Tasks から `executeLiveActivityRotation` を呼ぶときの共有シークレット */
export const TASK_SECRET = process.env.TASK_SECRET ?? "mamonaku-live-activity-task-secret";

/** 端末から APNs トピックが届いていない場合に使う既定値 */
export const DEFAULT_APNS_TOPIC = "sairyo.MAMONAKU.push-type.liveactivity";

/** Live Activity に同時に並べる予定の件数（無料: 1 / PLUS: 最大 3） */
export const MIN_VISIBLE_SLOTS = 1;
export const MAX_VISIBLE_SLOTS = 3;

/**
 * 表示件数を 1〜3 に収める。数値でなければ無料相当の 1 件。
 * 誤って 3 を既定値にすると、無料でもスタック表示になる。
 */
export function clampVisibleSlots(value: unknown): number {
  const slots = typeof value === "number" ? value : MIN_VISIBLE_SLOTS;
  return Math.min(Math.max(slots, MIN_VISIBLE_SLOTS), MAX_VISIBLE_SLOTS);
}
