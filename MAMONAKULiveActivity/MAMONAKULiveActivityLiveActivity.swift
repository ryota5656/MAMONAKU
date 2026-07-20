//
//  MAMONAKULiveActivityLiveActivity.swift
//  MAMONAKULiveActivity
//
//  Created by ryota.saito on 2026/01/18.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MAMONAKULiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var schedule: [ActivityTaskItem]
    }

    var name: String
}

struct ActivityTaskItem: Codable, Hashable {
    var nextTitle: String
    var nextStartDate: Date?
    /// プライマリスロットのカウントダウン終了時刻
    var nextEndDate: Date?
    /// カウントダウンの開始時刻（Live Activity 側ではこの固定レンジを使って更新させる）
    var countdownStartDate: Date?
    /// スタックスロットの相対時間、またはフォールバック表示用
    var remainingTimeShort: String
    var bufferMinutes: Int?
}

struct MAMONAKULiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MAMONAKULiveActivityAttributes.self) { context in
            StackLiveActivityView(schedule: context.state.schedule)
                .activityBackgroundTint(.clear)

        } dynamicIsland: { context in
            let primary = context.state.schedule.first
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(primary?.nextTitle ?? "完了")
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let primary {
                        PrimaryCountdownView(item: primary, fontSize: 10)
                    }
                }
            } compactLeading: {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .semibold))
            } compactTrailing: {
                if let primary {
                    PrimaryCountdownView(item: primary, fontSize: 10)
                } else {
                    Text("--:--")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
            } minimal: {
                if let primary {
                    PrimaryCountdownView(item: primary, fontSize: 10)
                } else {
                    Text("--")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
            }
        }
    }
}

// MARK: - Lock Screen / Banner

private struct StackLiveActivityView: View {
    let schedule: [ActivityTaskItem]

    private var primary: ActivityTaskItem? { schedule.first }
    private var stackItems: [ActivityTaskItem] { Array(schedule.dropFirst().prefix(2)) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            primarySection(primary: primary)

            if !stackItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(stackItems.enumerated()), id: \.offset) { _, item in
                        StackSlotView(item: item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private func primarySection(primary: ActivityTaskItem?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let primary {
                Text(primary.nextTitle)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)

                PrimaryCountdownView(item: primary, fontSize: 30, weight: .heavy)

                if let bufferMinutes = primary.bufferMinutes {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if let startDate = primary.nextStartDate {
                            let seconds = max(0, Int(startDate.timeIntervalSince(context.date)))
                            if seconds > 0, seconds <= bufferMinutes * 60, !primary.nextTitle.isEmpty {
                                Text("まもなく「\(primary.nextTitle)」です。準備をしましょう")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            } else {
                Text("NO PLAN")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: stackItems.isEmpty ? .infinity : nil, alignment: .leading)
        
    }
}

private struct StackSlotView: View {
    let item: ActivityTaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.remainingTimeShort)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(item.nextTitle)
                .font(.caption2)
                .lineLimit(2)
            if let bufferMinutes = item.bufferMinutes {
                Text("バッファ \(bufferMinutes)分")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shared countdown views

/// プライマリスロット: 次の予定の開始時刻までカウントダウン。
private struct PrimaryCountdownView: View {
    let item: ActivityTaskItem
    var fontSize: CGFloat = 30
    var weight: Font.Weight = .heavy

    private static let compactWidth: CGFloat = 32

    var body: some View {
        Group {
            if let target = item.nextStartDate {
                CountdownText(
                    startDate: item.countdownStartDate,
                    targetDate: target
                )
                .font(.system(size: fontSize, weight: weight, design: .rounded))
                .monospacedDigit()
                // push 更新でプライマリが切り替わったとき、timerInterval を必ず再生成する
                .id(target.timeIntervalSinceReferenceDate)
            } else {
                Text(item.remainingTimeShort.isEmpty ? "--:--" : item.remainingTimeShort)
                    .font(.system(size: fontSize, weight: weight, design: .rounded))
                    .monospacedDigit()
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .frame(width: fontSize <= 12 ? Self.compactWidth : nil, alignment: .trailing)
    }
}

private struct CompactCountdownView: View {
    let countdownStartDate: Date?
    let targetDate: Date?
    let fallbackText: String

    private static let font = Font.system(size: 10, weight: .medium, design: .monospaced)
    private static let fixedWidth: CGFloat = 32

    var body: some View {
        Group {
            if let targetDate {
                CountdownText(
                    startDate: countdownStartDate,
                    targetDate: targetDate
                )
                .id(targetDate.timeIntervalSinceReferenceDate)
                .font(Self.font)
                .monospacedDigit()
            } else {
                Text(fallbackText.isEmpty ? "--:--" : fallbackText)
                    .font(Self.font)
                    .monospacedDigit()
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .frame(width: Self.fixedWidth, alignment: .trailing)
    }
}

private struct CountdownText: View {
    let startDate: Date?
    let targetDate: Date

    var body: some View {
        let timerStart = effectiveTimerStart(now: Date())
        if targetDate > timerStart {
            Text(timerInterval: timerStart...targetDate, pauseTime: nil, countsDown: true)
        } else {
            Text("0:00")
        }
    }

    /// ペイロードの countdownStartDate が古い・不正でも、常に有効なカウントダウン区間を作る。
    private func effectiveTimerStart(now: Date) -> Date {
        if let startDate, startDate < targetDate {
            return min(startDate, now)
        }
        // 開始時刻が無い／不正な場合は終了の1時間前を固定アンカーにする
        return targetDate.addingTimeInterval(-3600)
    }
}

extension MAMONAKULiveActivityAttributes {
    fileprivate static var preview: MAMONAKULiveActivityAttributes {
        MAMONAKULiveActivityAttributes(name: "timeline-stack")
    }
}

extension MAMONAKULiveActivityAttributes.ContentState {
    fileprivate static func sampleSchedule(now: Date = .now) -> Self {
        let primaryStart = now.addingTimeInterval(25 * 60)
        let secondStart = now.addingTimeInterval(90 * 60)
        let thirdStart = now.addingTimeInterval(150 * 60)
        return Self(
            schedule: [
                ActivityTaskItem(
                    nextTitle: "ミーティング",
                    nextStartDate: primaryStart,
                    nextEndDate: primaryStart.addingTimeInterval(30 * 60),
                    countdownStartDate: now,
                    remainingTimeShort: "25分",
                    bufferMinutes: 10
                ),
                ActivityTaskItem(
                    nextTitle: "ランチ",
                    nextStartDate: secondStart,
                    nextEndDate: secondStart.addingTimeInterval(45 * 60),
                    countdownStartDate: nil,
                    remainingTimeShort: "1時間30分",
                    bufferMinutes: 5
                ),
                ActivityTaskItem(
                    nextTitle: "買い物",
                    nextStartDate: thirdStart,
                    nextEndDate: thirdStart.addingTimeInterval(40 * 60),
                    countdownStartDate: nil,
                    remainingTimeShort: "2時間30分",
                    bufferMinutes: nil
                ),
            ]
        )
    }

    fileprivate static func samplePrimaryOnly(now: Date = .now) -> Self {
        let primaryStart = now.addingTimeInterval(12 * 60)
        return Self(
            schedule: [
                ActivityTaskItem(
                    nextTitle: "ジム",
                    nextStartDate: primaryStart,
                    nextEndDate: primaryStart.addingTimeInterval(60 * 60),
                    countdownStartDate: now,
                    remainingTimeShort: "12分",
                    bufferMinutes: 15
                ),
            ]
        )
    }

    fileprivate static func sampleSoonBuffer(now: Date = .now) -> Self {
        let primaryStart = now.addingTimeInterval(4 * 60)
        return Self(
            schedule: [
                ActivityTaskItem(
                    nextTitle: "出発",
                    nextStartDate: primaryStart,
                    nextEndDate: primaryStart.addingTimeInterval(20 * 60),
                    countdownStartDate: now.addingTimeInterval(-20 * 60),
                    remainingTimeShort: "4分",
                    bufferMinutes: 10
                ),
                ActivityTaskItem(
                    nextTitle: "帰宅",
                    nextStartDate: now.addingTimeInterval(80 * 60),
                    nextEndDate: nil,
                    countdownStartDate: nil,
                    remainingTimeShort: "1時間20分",
                    bufferMinutes: nil
                ),
            ]
        )
    }

    fileprivate static var sampleEmpty: Self {
        Self(schedule: [])
    }
}

#Preview("Lock Screen - Stack", as: .content, using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.sampleSchedule()
}

#Preview("Lock Screen - Primary Only", as: .content, using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.samplePrimaryOnly()
}

#Preview("Lock Screen - Soon Buffer", as: .content, using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.sampleSoonBuffer()
}

#Preview("Lock Screen - Empty", as: .content, using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.sampleEmpty
}

#Preview("Dynamic Island - Compact", as: .dynamicIsland(.compact), using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.sampleSchedule()
}

#Preview("Dynamic Island - Expanded", as: .dynamicIsland(.expanded), using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.sampleSchedule()
}

#Preview("Dynamic Island - Minimal", as: .dynamicIsland(.minimal), using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.sampleSchedule()
    MAMONAKULiveActivityAttributes.ContentState.sampleEmpty
}
