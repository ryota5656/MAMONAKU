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
            let theme = AppPalette.loadFromAppGroup()
            StackLiveActivityView(schedule: context.state.schedule, theme: theme)
        } dynamicIsland: { context in
            let primary = context.state.schedule.first
            let theme = AppPalette.loadFromAppGroup()
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
            .keylineTint(AppColors.accent(palette: theme, environmentScheme: .light))
        }
    }
}

// MARK: - Lock Screen / Banner

private struct StackLiveActivityView: View {
    let schedule: [ActivityTaskItem]
    let theme: AppPalette
    @Environment(\.colorScheme) private var colorScheme

    private var primary: ActivityTaskItem? { schedule.first }
    private var stackItems: [ActivityTaskItem] { Array(schedule.dropFirst().prefix(2)) }

    private var displayScheme: ColorScheme {
        switch theme {
        case .light, .pop, .sakura:
            return .light
        case .dark, .elegant:
            return .dark
        case .system:
            return colorScheme
        @unknown default:
            return colorScheme
        }
    }

    var body: some View {
        let primaryColor = AppColors.textPrimary(palette: theme, environmentScheme: displayScheme)
        let secondaryColor = AppColors.textSecondary(palette: theme, environmentScheme: displayScheme)
        let accent = AppColors.accent(palette: theme, environmentScheme: displayScheme)
        let background = AppColors.background(palette: theme, environmentScheme: displayScheme)

        HStack(alignment: .top, spacing: 12) {
            primarySection(primary: primary, primaryColor: primaryColor, accent: accent)

            if !stackItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(stackItems.enumerated()), id: \.offset) { _, item in
                        StackSlotView(item: item, textColor: secondaryColor, accent: accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(primaryColor.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func primarySection(
        primary: ActivityTaskItem?,
        primaryColor: Color,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let primary {
                Text(primary.nextTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(primaryColor)
                    .lineLimit(2)

                PrimaryCountdownView(item: primary, fontSize: 30, weight: .heavy)
                    .foregroundStyle(primaryColor.opacity(0.95))

                if let bufferMinutes = primary.bufferMinutes {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if let startDate = primary.nextStartDate {
                            let seconds = max(0, Int(startDate.timeIntervalSince(context.date)))
                            if seconds > 0, seconds <= bufferMinutes * 60, !primary.nextTitle.isEmpty {
                                Text("まもなく「\(primary.nextTitle)」です。準備をしましょう")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(accent)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            } else {
                Text("NO PLAN")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(primaryColor.opacity(0.8))
            }
        }
        .frame(maxWidth: stackItems.isEmpty ? .infinity : nil, alignment: .leading)
    }
}

private struct StackSlotView: View {
    let item: ActivityTaskItem
    let textColor: Color
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.remainingTimeShort)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent.opacity(0.9))
            Text(item.nextTitle)
                .font(.caption2)
                .foregroundStyle(textColor)
                .lineLimit(2)
            if let bufferMinutes = item.bufferMinutes {
                Text("バッファ \(bufferMinutes)分")
                    .font(.caption2)
                    .foregroundStyle(textColor.opacity(0.7))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(textColor.opacity(0.06))
        )
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
        MAMONAKULiveActivityAttributes(name: "World")
    }
}
