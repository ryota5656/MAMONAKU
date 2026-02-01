//
//  MAMONAKULiveActivity.swift
//  MAMONAKULiveActivity
//
//  Created by ryota.saito on 2026/01/18.
//

import WidgetKit
import SwiftUI
import Foundation

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(
            date: Date(),
            nextTitle: "次の予定",
            nextStartDate: Date().addingTimeInterval(25 * 60)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> ()) {
        let entry = CountdownEntry(
            date: Date(),
            nextTitle: "次の予定",
            nextStartDate: Date().addingTimeInterval(25 * 60)
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> ()) {
        let currentDate = Date()
        let items = WidgetTimelineStore.loadItems()
        let next = WidgetTimelineStore.nextItem(after: currentDate, items: items)
        let nextStartDate = next.flatMap { WidgetTimelineStore.startDate(for: $0, baseDate: currentDate) }
        let entry = CountdownEntry(
            date: currentDate,
            nextTitle: next?.title,
            nextStartDate: nextStartDate
        )

        let refreshDate: Date
        if let nextStartDate {
            refreshDate = max(nextStartDate, currentDate).addingTimeInterval(1)
        } else {
            refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(15 * 60)
        }

        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct CountdownEntry: TimelineEntry {
    let date: Date
    let nextTitle: String?
    let nextStartDate: Date?
}

struct MAMONAKULiveActivityEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 6) {
            Text("次の予定まで")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let nextStartDate = entry.nextStartDate {
                CountdownText(targetDate: nextStartDate)
                    .font(.headline.monospacedDigit())

                if let nextTitle = entry.nextTitle {
                    Text("\(nextTitle) \(nextStartDate, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("予定なし")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MAMONAKULiveActivity: Widget {
    let kind: String = "MAMONAKULiveActivity"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                MAMONAKULiveActivityEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MAMONAKULiveActivityEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("次の予定カウントダウン")
        .description("次の予定までの残り時間を表示します。")
    }
}

#Preview(as: .systemSmall) {
    MAMONAKULiveActivity()
} timeline: {
    CountdownEntry(date: .now, nextTitle: "作業", nextStartDate: Date().addingTimeInterval(20 * 60))
    CountdownEntry(date: .now, nextTitle: nil, nextStartDate: nil)
}

private struct CountdownText: View {
    let targetDate: Date

    var body: some View {
        let now = Date()
        let end = max(now, targetDate)
        return Text(timerInterval: now...end, pauseTime: nil, countsDown: true)
    }
}

private enum WidgetTimelineStore {
    private static let storageKey = "timeline_items"
    private static let appGroupID = "group.sairyo.MAMONAKU"

    static func loadItems() -> [WidgetTimelineItem] {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([WidgetTimelineItem].self, from: data)
        } catch {
            return []
        }
    }

    static func nextItem(after date: Date, items: [WidgetTimelineItem]) -> WidgetTimelineItem? {
        let nowSeconds = secondsSinceMidnight(date: date)
        let startMinutes = Int(ceil(Double(nowSeconds) / 60.0))
        let candidates = items.compactMap { item -> (WidgetTimelineItem, Int)? in
            guard let dropDate = item.dropDate,
                  Calendar.current.isDateInToday(dropDate),
                  let minutes = item.startMinutes else {
                return nil
            }
            return (item, minutes)
        }

        return candidates
            .filter { $0.1 >= startMinutes }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    static func startDate(for item: WidgetTimelineItem, baseDate: Date) -> Date? {
        guard let minutes = item.startMinutes else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: baseDate)
        return Calendar.current.date(byAdding: .minute, value: minutes, to: startOfDay)
    }

    private static func secondsSinceMidnight(date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let s = comps.second ?? 0
        return (h * 3600) + (m * 60) + s
    }
}

private struct WidgetTimelineItem: Identifiable, Codable {
    let id: UUID
    let title: String
    var durationMinutes: Int
    var startMinutes: Int?
    var dropDate: Date?
}
