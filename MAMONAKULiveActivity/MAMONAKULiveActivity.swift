////
////  MAMONAKULiveActivity.swift
////  MAMONAKULiveActivity
////
////  Created by ryota.saito on 2026/01/18.
////
//
//import WidgetKit
//import SwiftUI
//import Foundation
//
//struct Provider: TimelineProvider {
//    func placeholder(in context: Context) -> CountdownEntry {
//        CountdownEntry(
//            date: Date(),
//            nextTitle: "次の予定１",
//            nextStartDate: Date().addingTimeInterval(25 * 60)
//        )
//    }
//
//    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> ()) {
//        let entry = CountdownEntry(
//            date: Date(),
//            nextTitle: "次の予定２",
//            nextStartDate: Date().addingTimeInterval(25 * 60)
//        )
//        completion(entry)
//    }
//
//    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> ()) {
//        let currentDate = Date()
//        if let summary = WidgetTimelineStore.loadNextSummary() {
//            let entry = CountdownEntry(
//                date: currentDate,
//                nextTitle: summary.title,
//                nextStartDate: summary.startDate
//            )
//            let refreshDate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate) ?? currentDate.addingTimeInterval(60)
//            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
//            return
//        }
//
//        let items = WidgetTimelineStore.loadItems()
//        let next = WidgetTimelineStore.nextItem(after: currentDate, items: items)
//        let nextStartDate = next.flatMap { WidgetTimelineStore.startDate(for: $0, baseDate: currentDate) }
//        let entry = CountdownEntry(
//            date: currentDate,
//            nextTitle: next?.title,
//            nextStartDate: nextStartDate
//        )
//
//        let refreshDate: Date
//        if let nextStartDate {
//            refreshDate = max(nextStartDate, currentDate).addingTimeInterval(1)
//        } else {
//            refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(15 * 60)
//        }
//
//        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
//    }
//}
//
//struct CountdownEntry: TimelineEntry {
//    let date: Date
//    let nextTitle: String?
//    let nextStartDate: Date?
//}
//
//struct MAMONAKULiveActivity: Widget {
//    let kind: String = "MAMONAKULiveActivity"
//
//    var body: some WidgetConfiguration {
//        StaticConfiguration(kind: kind, provider: Provider()) { entry in
//                MAMONAKULiveActivityEntryView(entry: entry)
//                    .padding()
//                    .containerBackground(.fill.tertiary, for: .widget)
//        }
//        .configurationDisplayName("次の予定カウントダウン")
//        .description("次の予定までの残り時間を表示します。")
//    }
//}
//
//struct MAMONAKULiveActivityEntryView: View {
//    var entry: Provider.Entry
//    @Environment(\.widgetFamily) private var widgetFamily
//
//    var body: some View {
//        let theme = AppPalette.loadFromAppGroup()
//        CountdownHeaderCard(
//            nextTitle: entry.nextTitle,
//            nextStartDate: entry.nextStartDate,
//            isCompact: widgetFamily == .systemSmall,
//            theme: theme
//        )
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//}
//
//#Preview(as: .systemSmall) {
//    MAMONAKULiveActivity()
//} timeline: {
//    CountdownEntry(date: .now, nextTitle: "作業", nextStartDate: Date().addingTimeInterval(20 * 60))
//    CountdownEntry(date: .now, nextTitle: nil, nextStartDate: nil)
//}
//
//#Preview(as: .systemMedium) {
//    MAMONAKULiveActivity()
//} timeline: {
//    CountdownEntry(date: .now, nextTitle: "作業", nextStartDate: Date().addingTimeInterval(20 * 60))
//    CountdownEntry(date: .now, nextTitle: nil, nextStartDate: nil)
//}
//
//private struct CountdownText: View {
//    let targetDate: Date
//
//    var body: some View {
//        if targetDate > .now {
//            Text(targetDate, style: .timer)
//        } else {
//            Text("0:00")
//        }
//    }
//}
//
//private struct CountdownHeaderCard: View {
//    let nextTitle: String?
//    let nextStartDate: Date?
//    var isCompact: Bool = false
//    let theme: AppPalette
//    @Environment(\.colorScheme) private var colorScheme
//
//    private var displayScheme: ColorScheme {
//        switch theme {
//        case .light, .pop:
//            return .light
//        case .dark, .elegant:
//            return .dark
//        case .system:
//            return colorScheme
//        @unknown default:
//            return colorScheme
//        }
//    }
//
//    private func remainingSeconds(at currentDate: Date) -> Int? {
//        guard let nextStartDate else { return nil }
//        return max(0, Int(nextStartDate.timeIntervalSince(currentDate)))
//    }
//
//    private var spacing: CGFloat { isCompact ? 4 : 10 }
//    private var titleFont: Font { .system(size: isCompact ? 9 : 10, weight: .semibold) }
//    private var countdownFont: Font { .system(size: isCompact ? 20 : 30, weight: .heavy, design: .rounded) }
//    private var noPlanFont: Font { .system(size: isCompact ? 16 : 24, weight: .heavy, design: .rounded) }
//
//    var body: some View {
//        let accent = AppColors.accent(palette: theme, environmentScheme: displayScheme)
//        let primary = AppColors.textPrimary(palette: theme, environmentScheme: displayScheme)
//        VStack(alignment: .leading, spacing: spacing) {
//            // 1. タイトル（ラベル + 予定名）
//            VStack(alignment: .leading, spacing: 2) {
//                Text(nextStartDate != nil ? "Next event in..." : "Today's Status")
//                    .font(titleFont)
//                    .foregroundStyle(primary.opacity(0.6))
//                if let nextTitle, !nextTitle.isEmpty {
//                    Text(nextTitle)
//                        .font(.system(size: isCompact ? 11 : 14, weight: .medium))
//                        .foregroundStyle(primary.opacity(0.7))
//                        .lineLimit(isCompact ? 1 : 2)
//                }
//            }
//
//            // 2. 時間（カウントダウン or NO PLAN）
//            if let nextStartDate {
//                CountdownText(targetDate: nextStartDate)
//                    .font(countdownFont)
//                    .foregroundStyle(primary)
//            } else {
//                Text("NO PLAN")
//                    .font(noPlanFont)
//                    .foregroundStyle(primary.opacity(0.8))
//            }
//
//            // 3. プログレスバー
//            if let seconds = remainingSeconds(at: .now), seconds <= 3600 {
//                CountdownProgressBar(secondsRemaining: seconds, accent: accent)
//            }
//        }
//    }
//}
//
//private struct CountdownProgressBar: View {
//    let secondsRemaining: Int
//    let accent: Color
//
//    private var clampedSeconds: Int {
//        max(0, min(3600, secondsRemaining))
//    }
//
//    private var progress: CGFloat {
//        1.0 - (CGFloat(clampedSeconds) / 3600.0)
//    }
//
//    var body: some View {
//        GeometryReader { proxy in
//            let width = proxy.size.width
//            ZStack(alignment: .leading) {
//                Capsule()
//                    .fill(Color.primary.opacity(0.08))
//                Capsule()
//                    .fill(accent)
//                    .frame(width: max(6, width * progress))
//                HStack(spacing: 0) {
//                    ForEach(0..<5, id: \.self) { _ in
//                        Circle()
//                            .fill(accent)
//                            .frame(width: 5, height: 5)
//                            .opacity(0.25)
//                            .frame(maxWidth: .infinity)
//                    }
//                }
//                .padding(.horizontal, 4)
//            }
//        }
//        .frame(height: 10)
//        .frame(maxWidth: .infinity)
//    }
//}
//
//private enum WidgetTimelineStore {
//    private static let storageKey = "timeline_items"
//    private static let nextItemKey = "timeline_next_item"
//    private static let appGroupID = "group.sairyo.MAMONAKU"
//
//    static func loadItems() -> [WidgetTimelineItem] {
//        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
//        guard let data = defaults.data(forKey: storageKey) else { return [] }
//        do {
//            let decoder = JSONDecoder()
//            decoder.dateDecodingStrategy = .iso8601
//            return try decoder.decode([WidgetTimelineItem].self, from: data)
//        } catch {
//            return []
//        }
//    }
//
//    static func loadNextSummary() -> WidgetNextItemSummary? {
//        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
//        guard let data = defaults.data(forKey: nextItemKey) else { return nil }
//        do {
//            let decoder = JSONDecoder()
//            decoder.dateDecodingStrategy = .iso8601
//            return try decoder.decode(WidgetNextItemSummary.self, from: data)
//        } catch {
//            return nil
//        }
//    }
//
//    static func nextItem(after date: Date, items: [WidgetTimelineItem]) -> WidgetTimelineItem? {
//        let nowSeconds = secondsSinceMidnight(date: date)
//        let startMinutes = Int(ceil(Double(nowSeconds) / 60.0))
//        let candidates = items.compactMap { item -> (WidgetTimelineItem, Int)? in
//            guard let dropDate = item.dropDate,
//                  Calendar.current.isDateInToday(dropDate),
//                  let minutes = item.startMinutes else {
//                return nil
//            }
//            return (item, minutes)
//        }
//
//        return candidates
//            .filter { $0.1 >= startMinutes }
//            .min(by: { $0.1 < $1.1 })?
//            .0
//    }
//
//    static func startDate(for item: WidgetTimelineItem, baseDate: Date) -> Date? {
//        guard let minutes = item.startMinutes else { return nil }
//        let startOfDay = Calendar.current.startOfDay(for: baseDate)
//        return Calendar.current.date(byAdding: .minute, value: minutes, to: startOfDay)
//    }
//
//    private static func secondsSinceMidnight(date: Date) -> Int {
//        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
//        let h = comps.hour ?? 0
//        let m = comps.minute ?? 0
//        let s = comps.second ?? 0
//        return (h * 3600) + (m * 60) + s
//    }
//
//}
//
//private struct WidgetTimelineItem: Identifiable, Codable {
//    let id: UUID
//    let title: String
//    var durationMinutes: Int
//    var startMinutes: Int?
//    var dropDate: Date?
//}
//
//private struct WidgetNextItemSummary: Codable {
//    let title: String
//    let startDate: Date?
//}
