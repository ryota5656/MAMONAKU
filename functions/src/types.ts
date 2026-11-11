/**
 * Live Activity の content-state に載せる予定 1 件分。
 * 日時は Swift の `Date` に合わせ、2001-01-01 からの秒数（reference date seconds）で表す。
 */
export interface TaskItemPayload {
  nextTitle: string;
  nextStartDate?: number;
  nextEndDate?: number;
  countdownStartDate?: number;
  remainingTimeShort: string;
  bufferMinutes?: number;
}

/** 予定の開始時刻ごとに Live Activity を切り替える予約 1 件分 */
export interface RotationPayload {
  switchAtUnix: number;
  schedule: TaskItemPayload[];
  shouldEndActivity: boolean;
  reason?: string;
}

/** 当日の予定（終日・未配置・削除済みを除いたもの） */
export interface ScheduledEntry {
  id: string;
  title: string;
  startDate: Date;
  endDate: Date;
  bufferMinutes?: number;
}

/** Firestore の Timestamp のうち、ここで使う部分 */
export interface TimestampLike {
  toDate(): Date;
}

/** `users/{uid}/schedules/{id}` ドキュメント */
export interface ScheduleDoc {
  title?: string;
  durationMinutes?: number;
  startMinutes?: number | null;
  dropDate?: TimestampLike | null;
  startDate?: TimestampLike | null;
  endDate?: TimestampLike | null;
  isAllDay?: boolean;
  deleted?: boolean;
  bufferMinutes?: number | null;
}

/** Live Activity へプッシュするための宛先 */
export interface PushTarget {
  fcmToken: string;
  liveActivityToken: string;
  apnsTopic: string;
}
