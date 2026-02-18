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
            nextTitle: "次の予定１",
            nextStartDate: Date().addingTimeInterval(25 * 60)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> ()) {
        let entry = CountdownEntry(
            date: Date(),
            nextTitle: "次の予定２",
            nextStartDate: Date().addingTimeInterval(25 * 60)
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> ()) {
        let currentDate = Date()
        if let summary = WidgetTimelineStore.loadNextSummary() {
            let entry = CountdownEntry(
                date: currentDate,
                nextTitle: summary.title,
                nextStartDate: summary.startDate
            )
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate) ?? currentDate.addingTimeInterval(60)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
            return
        }

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

struct MAMONAKULiveActivity: Widget {
    let kind: String = "MAMONAKULiveActivity"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
                MAMONAKULiveActivityEntryView(entry: entry)
                    .padding()
                    .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("次の予定カウントダウン")
        .description("次の予定までの残り時間を表示します。")
    }
}

struct MAMONAKULiveActivityEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        CountdownHeaderCard(
            nextTitle: entry.nextTitle,
            nextStartDate: entry.nextStartDate
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .light)

    }
}

#Preview(as: .systemMedium) {
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

private struct CountdownHeaderCard: View {
    let nextTitle: String?
    let nextStartDate: Date?

    private var remainingSeconds: Int? {
        guard let nextStartDate else { return nil }
        return max(0, Int(nextStartDate.timeIntervalSinceNow))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("次の予定まで")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let nextStartDate {
                        CountdownText(targetDate: nextStartDate)
                            .font(.headline.monospacedDigit())
                    } else {
                        Text("予定なし")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let nextTitle, let nextStartDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(nextStartDate, style: .time)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(nextTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.06))
                    )
                }
            }

            if let seconds = remainingSeconds, seconds <= 3600 {
                CountdownProgressBar(secondsRemaining: seconds)
            }
        }
//        .padding(14)
//        .background(
//            RoundedRectangle(cornerRadius: 16, style: .continuous)
//                .fill(Color(.systemBackground))
//        )
//        .overlay(
//            RoundedRectangle(cornerRadius: 16, style: .continuous)
//                .stroke(Color.black.opacity(0.08), lineWidth: 1)
//        )
    }
}

private struct CountdownProgressBar: View {
    let secondsRemaining: Int

    private var clampedSeconds: Int {
        max(0, min(3600, secondsRemaining))
    }

    private var progress: CGFloat {
        1.0 - (CGFloat(clampedSeconds) / 3600.0)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))
                Capsule()
                    .fill(Color.black)
                    .frame(width: max(6, width * progress))
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.black)
                            .frame(width: 5, height: 5)
                            .opacity(0.35)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 10)
        .frame(maxWidth: .infinity)
    }
}

private enum WidgetTimelineStore {
    private static let storageKey = "timeline_items"
    private static let nextItemKey = "timeline_next_item"
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

    static func loadNextSummary() -> WidgetNextItemSummary? {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard let data = defaults.data(forKey: nextItemKey) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WidgetNextItemSummary.self, from: data)
        } catch {
            return nil
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

private struct WidgetNextItemSummary: Codable {
    let title: String
    let startDate: Date?
}
