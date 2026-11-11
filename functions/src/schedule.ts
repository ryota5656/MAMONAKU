import { ScheduleDoc, ScheduledEntry, RotationPayload, TaskItemPayload } from "./types.js";
import {
  isSameTokyoDay,
  referenceDateSecondsToUnix,
  shortCountdown,
  stackTimeLabel,
  startOfDayTokyo,
  toReferenceDateSeconds,
  toUnixSeconds,
} from "./time.js";

/** 所要時間が保存されていない予定の長さ（分） */
const DEFAULT_DURATION_MINUTES = 30;
const DEFAULT_TITLE = "予定";

/** schedules ドキュメントを、`today` のタイムラインに置かれた予定へ変換する。対象外なら null。 */
export function toScheduledEntry(id: string, data: ScheduleDoc, today: Date): ScheduledEntry | null {
  if (data.deleted === true || data.isAllDay === true) return null;
  if (data.startMinutes === null || data.startMinutes === undefined) return null;
  if (!data.dropDate) return null;

  const dropDate = data.dropDate.toDate();
  if (!isSameTokyoDay(dropDate, today)) return null;

  const duration = data.durationMinutes ?? DEFAULT_DURATION_MINUTES;
  let startDate: Date;
  let endDate: Date;
  if (data.startDate) {
    startDate = data.startDate.toDate();
    endDate = data.endDate ? data.endDate.toDate() : addMinutes(startDate, duration);
  } else {
    startDate = addMinutes(startOfDayTokyo(dropDate), data.startMinutes);
    endDate = addMinutes(startDate, duration);
  }

  return {
    id,
    title: data.title ?? DEFAULT_TITLE,
    startDate,
    endDate,
    bufferMinutes: data.bufferMinutes ?? undefined,
  };
}

/** schedules ドキュメント群から、当日の予定を開始時刻順に並べる。 */
export function todayEntries(docs: { id: string; data: ScheduleDoc }[], now: Date): ScheduledEntry[] {
  const today = startOfDayTokyo(now);
  return docs
    .map((doc) => toScheduledEntry(doc.id, doc.data, today))
    .filter((entry): entry is ScheduledEntry => entry !== null)
    .sort((a, b) => a.startDate.getTime() - b.startDate.getTime());
}

/**
 * 今表示すべき予定。まだ始まっていない最初の予定から最大 `maxVisibleSlots` 件。
 * `startIndex` は `window` の先頭の位置（すべて始まっていれば `entries.length`）。
 */
export function currentWindow(
  entries: ScheduledEntry[],
  now: Date,
  maxVisibleSlots: number
): { startIndex: number; window: ScheduledEntry[] } {
  const firstUpcoming = entries.findIndex((e) => e.startDate.getTime() > now.getTime());
  const startIndex = firstUpcoming === -1 ? entries.length : firstUpcoming;
  return {
    startIndex,
    window: entries.slice(startIndex, startIndex + maxVisibleSlots),
  };
}

/** 表示する予定を content-state 用に変換する。先頭はカウントダウン、2 件目以降は開始時刻の目安を出す。 */
export function buildTaskItems(window: ScheduledEntry[], now: Date): TaskItemPayload[] {
  return window.map((entry, index) => {
    if (index === 0) {
      return {
        nextTitle: entry.title,
        nextStartDate: toReferenceDateSeconds(entry.startDate),
        nextEndDate: toReferenceDateSeconds(entry.endDate),
        countdownStartDate: toReferenceDateSeconds(now),
        remainingTimeShort: shortCountdown(entry.startDate, now),
        bufferMinutes: entry.bufferMinutes,
      };
    }
    return {
      nextTitle: entry.title,
      nextStartDate: toReferenceDateSeconds(entry.startDate),
      remainingTimeShort: stackTimeLabel(entry.startDate, now),
      bufferMinutes: entry.bufferMinutes,
    };
  });
}

/**
 * `startIndex` 以降の各予定の開始時刻に行う切り替え。
 * 開始した予定の次から最大 `maxVisibleSlots` 件を表示し、最後の予定が始まったら Live Activity を終える。
 */
export function buildRotations(
  entries: ScheduledEntry[],
  startIndex: number,
  now: Date,
  maxVisibleSlots: number
): RotationPayload[] {
  const isSingleSlot = maxVisibleSlots <= 1;
  const rotations: RotationPayload[] = [];

  for (let index = startIndex; index < entries.length; index += 1) {
    const switchAt = entries[index].startDate;
    if (switchAt.getTime() <= now.getTime()) continue;

    if (index === entries.length - 1) {
      rotations.push({
        switchAtUnix: toUnixSeconds(switchAt),
        schedule: [],
        shouldEndActivity: true,
        reason: isSingleSlot ? "free_single_event_started" : "last_event_started",
      });
      continue;
    }

    const window = entries.slice(index + 1, index + 1 + maxVisibleSlots);
    rotations.push({
      switchAtUnix: toUnixSeconds(switchAt),
      schedule: buildTaskItems(window, switchAt),
      shouldEndActivity: false,
      reason: isSingleSlot ? "free_next_single_event" : "next_event_countdown",
    });
  }
  return rotations;
}

/**
 * 送信直前にカウントダウンの起点を現在時刻へ合わせる（予約から時間が経っていても進捗表示がずれないように）。
 * 先頭の予定がすでに始まっている場合は、開始の 1 秒前を起点にする。
 */
export function refreshScheduleForPush(schedule: TaskItemPayload[], now: Date): TaskItemPayload[] {
  if (schedule.length === 0) return schedule;
  const [primary, ...rest] = schedule;
  const nowRef = toReferenceDateSeconds(now);
  const nextStart = primary.nextStartDate;
  return [
    {
      ...primary,
      countdownStartDate: nextStart !== undefined && nextStart <= nowRef ? nextStart - 1 : nowRef,
    },
    ...rest,
  ];
}

/** APNs の content-state。値の無い項目はキーごと省く（Swift 側の Optional として扱うため）。 */
export function buildContentState(schedule: TaskItemPayload[]): Record<string, unknown> {
  return {
    schedule: schedule.map((item) => {
      const mapped: Record<string, unknown> = {
        nextTitle: item.nextTitle,
        remainingTimeShort: item.remainingTimeShort,
      };
      if (item.nextStartDate !== undefined) mapped.nextStartDate = item.nextStartDate;
      if (item.nextEndDate !== undefined) mapped.nextEndDate = item.nextEndDate;
      if (item.countdownStartDate !== undefined) mapped.countdownStartDate = item.countdownStartDate;
      if (item.bufferMinutes !== undefined) mapped.bufferMinutes = item.bufferMinutes;
      return mapped;
    }),
  };
}

/** 先頭の予定の開始時刻（Unix 秒）。この時刻を過ぎた表示は古いとみなす。 */
export function primaryStaleDateUnix(schedule: TaskItemPayload[]): number | undefined {
  const primary = schedule[0];
  if (primary?.nextStartDate === undefined) return undefined;
  return referenceDateSecondsToUnix(primary.nextStartDate);
}

function addMinutes(date: Date, minutes: number): Date {
  return new Date(date.getTime() + minutes * 60_000);
}
