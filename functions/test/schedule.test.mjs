import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  buildContentState,
  buildRotations,
  buildTaskItems,
  currentWindow,
  primaryStaleDateUnix,
  refreshScheduleForPush,
  todayEntries,
} from "../lib/schedule.js";
import { toReferenceDateSeconds } from "../lib/time.js";
import { clampVisibleSlots } from "../lib/config.js";

/** 2026-11-11 (JST) の hh:mm */
const jst = (hour, minute = 0) => new Date(Date.UTC(2026, 10, 11, hour - 9, minute));
const timestamp = (date) => ({ toDate: () => date });
const entry = (id, startHour, durationMinutes = 30) => ({
  id,
  title: id,
  startDate: jst(startHour),
  endDate: new Date(jst(startHour).getTime() + durationMinutes * 60_000),
  bufferMinutes: undefined,
});

describe("todayEntries", () => {
  const now = jst(8);

  it("当日にタイムライン配置された予定だけを開始時刻順に返す", () => {
    const docs = [
      { id: "late", data: { title: "late", startMinutes: 18 * 60, dropDate: timestamp(jst(0)) } },
      { id: "early", data: { title: "early", startMinutes: 9 * 60, durationMinutes: 45, dropDate: timestamp(jst(12)) } },
      { id: "stock", data: { title: "stock", startMinutes: null, dropDate: timestamp(jst(0)) } },
      { id: "allDay", data: { title: "allDay", startMinutes: 0, isAllDay: true, dropDate: timestamp(jst(0)) } },
      { id: "deleted", data: { title: "deleted", startMinutes: 600, deleted: true, dropDate: timestamp(jst(0)) } },
      { id: "tomorrow", data: { title: "tomorrow", startMinutes: 600, dropDate: timestamp(jst(24 + 1)) } },
    ];

    const entries = todayEntries(docs, now);

    assert.deepEqual(entries.map((e) => e.id), ["early", "late"]);
    assert.deepEqual(entries[0].startDate, jst(9));
    assert.deepEqual(entries[0].endDate, jst(9, 45));
    // 所要時間が無ければ 30 分
    assert.deepEqual(entries[1].endDate, jst(18, 30));
  });

  it("startDate があればそれを使い、タイトルが無ければ「予定」にする", () => {
    const docs = [
      { id: "a", data: { startMinutes: 0, dropDate: timestamp(jst(0)), startDate: timestamp(jst(10)) } },
    ];

    const [result] = todayEntries(docs, now);

    assert.equal(result.title, "予定");
    assert.deepEqual(result.startDate, jst(10));
    assert.deepEqual(result.endDate, jst(10, 30));
  });
});

describe("currentWindow", () => {
  const entries = [entry("a", 9), entry("b", 10), entry("c", 11), entry("d", 12)];

  it("まだ始まっていない最初の予定から最大件数分を返す", () => {
    const { startIndex, window } = currentWindow(entries, jst(9, 30), 2);
    assert.equal(startIndex, 1);
    assert.deepEqual(window.map((e) => e.id), ["b", "c"]);
  });

  it("すべて始まっていれば空", () => {
    const { startIndex, window } = currentWindow(entries, jst(13), 3);
    assert.equal(startIndex, 4);
    assert.deepEqual(window, []);
  });
});

describe("buildTaskItems", () => {
  it("先頭はカウントダウン、2 件目以降は開始までの目安を出す", () => {
    const now = jst(9);
    const items = buildTaskItems([entry("a", 10), entry("b", 10, 60), entry("c", 12)], now);

    assert.equal(items[0].remainingTimeShort, "1:00");
    assert.equal(items[0].countdownStartDate, toReferenceDateSeconds(now));
    assert.equal(items[1].remainingTimeShort, "60分後");
    assert.equal(items[1].nextEndDate, undefined);
    assert.equal(items[2].remainingTimeShort, "12:00");
  });
});

describe("buildRotations", () => {
  const entries = [entry("a", 9), entry("b", 10), entry("c", 11)];

  it("各予定の開始時刻に次の予定へ切り替え、最後の予定の開始で終える", () => {
    const rotations = buildRotations(entries, 0, jst(8), 1);

    assert.deepEqual(
      rotations.map((r) => [r.reason, r.schedule.map((s) => s.nextTitle)]),
      [
        ["free_next_single_event", ["b"]],
        ["free_next_single_event", ["c"]],
        ["free_single_event_started", []],
      ]
    );
    assert.equal(rotations[2].shouldEndActivity, true);
    assert.equal(rotations[0].switchAtUnix, jst(9).getTime() / 1000);
  });

  it("スタック表示では次の予定から最大件数分を並べる", () => {
    const rotations = buildRotations(entries, 0, jst(8), 3);
    assert.deepEqual(rotations[0].schedule.map((s) => s.nextTitle), ["b", "c"]);
    assert.equal(rotations[0].reason, "next_event_countdown");
    assert.equal(rotations[2].reason, "last_event_started");
  });
});

describe("refreshScheduleForPush", () => {
  const [item] = buildTaskItems([entry("a", 10)], jst(8));

  it("カウントダウンの起点を送信時刻にする", () => {
    const [refreshed] = refreshScheduleForPush([item], jst(9));
    assert.equal(refreshed.countdownStartDate, toReferenceDateSeconds(jst(9)));
  });

  it("先頭の予定が始まっていれば、開始の 1 秒前を起点にする", () => {
    const [refreshed] = refreshScheduleForPush([item], jst(10, 5));
    assert.equal(refreshed.countdownStartDate, item.nextStartDate - 1);
  });
});

describe("buildContentState / primaryStaleDateUnix", () => {
  it("値の無い項目はキーごと省き、先頭の開始時刻を stale-date にする", () => {
    const items = buildTaskItems([entry("a", 10), entry("b", 11)], jst(9));
    const state = buildContentState(items);

    assert.deepEqual(Object.keys(state.schedule[1]).sort(), ["nextStartDate", "nextTitle", "remainingTimeShort"]);
    assert.equal(primaryStaleDateUnix(items), jst(10).getTime() / 1000);
    assert.equal(primaryStaleDateUnix([]), undefined);
  });
});

describe("clampVisibleSlots", () => {
  it("1〜3 に収め、数値でなければ 1 にする", () => {
    assert.equal(clampVisibleSlots(0), 1);
    assert.equal(clampVisibleSlots(2), 2);
    assert.equal(clampVisibleSlots(5), 3);
    assert.equal(clampVisibleSlots(undefined), 1);
    assert.equal(clampVisibleSlots("3"), 1);
  });
});
