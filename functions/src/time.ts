/** Unix 時刻と Swift の reference date（2001-01-01T00:00:00Z）の差（秒） */
export const REFERENCE_DATE_OFFSET_SEC = 978307200;

const TIME_ZONE = "Asia/Tokyo";
/** Asia/Tokyo は UTC+9 固定（夏時間なし） */
const TOKYO_UTC_OFFSET_HOURS = 9;

export function toReferenceDateSeconds(date: Date): number {
  return Math.floor(date.getTime() / 1000) - REFERENCE_DATE_OFFSET_SEC;
}

export function referenceDateSecondsToUnix(seconds: number): number {
  return Math.floor(seconds + REFERENCE_DATE_OFFSET_SEC);
}

export function toUnixSeconds(date: Date): number {
  return Math.floor(date.getTime() / 1000);
}

const tokyoDateFormatter = new Intl.DateTimeFormat("en-CA", {
  timeZone: TIME_ZONE,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

/** 東京時間でその日の 0 時 */
export function startOfDayTokyo(date: Date): Date {
  const parts = tokyoDateFormatter.formatToParts(date);
  const part = (type: Intl.DateTimeFormatPartTypes) => Number(parts.find((p) => p.type === type)?.value);
  return new Date(Date.UTC(part("year"), part("month") - 1, part("day"), -TOKYO_UTC_OFFSET_HOURS, 0, 0));
}

export function isSameTokyoDay(a: Date, b: Date): boolean {
  return startOfDayTokyo(a).getTime() === startOfDayTokyo(b).getTime();
}

/** 残り時間の短い表記。1 時間以上は「時:分」、未満は「分:秒」。 */
export function shortCountdown(to: Date, from: Date): string {
  const seconds = Math.max(0, Math.floor((to.getTime() - from.getTime()) / 1000));
  if (seconds >= 3600) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}:${String(minutes).padStart(2, "0")}`;
  }
  const minutes = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${minutes}:${String(secs).padStart(2, "0")}`;
}

const tokyoTimeFormatter = new Intl.DateTimeFormat("ja-JP", {
  timeZone: TIME_ZONE,
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
});

/** スタック表示の 2 件目以降に添える時刻。2 時間未満は「N分後」、それ以降は「HH:mm」。 */
export function stackTimeLabel(startDate: Date, now: Date): string {
  const minutes = Math.max(0, Math.floor((startDate.getTime() - now.getTime()) / 60000));
  if (minutes < 120) return `${minutes}分後`;
  return tokyoTimeFormatter.format(startDate);
}
