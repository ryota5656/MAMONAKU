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
        var nextTitle: String
        var nextStartDate: Date?
        /// カウントダウンの開始時刻（Live Activity 側ではこの固定レンジを使って更新させる）
        var countdownStartDate: Date?
        /// nextStartDate がない時のフォールバック表示用。
        var remainingTimeShort: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MAMONAKULiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration{
        ActivityConfiguration(for: MAMONAKULiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            let theme = AppPalette.loadFromAppGroup()
            CountdownHeaderCard(
                nextTitle: context.state.nextTitle,
                nextStartDate: context.state.nextStartDate,
                countdownStartDate: context.state.countdownStartDate,
                theme: theme
            )
            
        } dynamicIsland: { context in
            DynamicIsland {
                // 長押し時: タイトルと開始時間を表示
                DynamicIslandExpandedRegion(.leading) {
                    if let startDate = context.state.nextStartDate {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(startDate, style: .time)
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                        .padding(.leading, 20)
                    } else {
                        Text("--:--")
                            .font(.subheadline.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let startDate = context.state.nextStartDate {
                        CountdownText(
                            startDate: context.state.countdownStartDate ?? Date(),
                            targetDate: startDate
                        )
                            .font(.caption.monospacedDigit())
                    } else {
                        Text("--:--")
                            .font(.caption.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.nextTitle.isEmpty ? "NO PLAN" : context.state.nextTitle)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                    }
                    .padding(.leading, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                // 通常時: 残り時間（拡張内タイマーで更新するためバックグラウンドでも止まらない）
                CompactCountdownView(
                    countdownStartDate: context.state.countdownStartDate,
                    nextStartDate: context.state.nextStartDate,
                    fallbackText: context.state.remainingTimeShort
                )
            } minimal: {
                // 最小表示: 残り時間（同上）
                CompactCountdownView(
                    countdownStartDate: context.state.countdownStartDate,
                    nextStartDate: context.state.nextStartDate,
                    fallbackText: context.state.remainingTimeShort
                )
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.primary)
        }
    }
}

/// Compact/Minimal 用のカウントダウン。nextStartDate がある場合は Text(timerInterval:) でシステムが更新するためバックグラウンドでも止まらない。
/// 横幅を以前の remainingTimeShort（例: 25:00）と同一に保つため固定幅を指定。
private struct CompactCountdownView: View {
    let countdownStartDate: Date?
    let nextStartDate: Date?
    let fallbackText: String

    private static let font = Font.system(size: 10, weight: .medium, design: .monospaced)
    /// "25:00" / "1:23" 程度の幅（size 10 monospaced で約5文字分）
    private static let fixedWidth: CGFloat = 32

    var body: some View {
        Group {
            if let nextStartDate {
                CountdownText(
                    startDate: countdownStartDate ?? Date(),
                    targetDate: nextStartDate
                )
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
    let startDate: Date
    let targetDate: Date

    var body: some View {
        if targetDate > startDate {
            Text(timerInterval: startDate...targetDate, pauseTime: nil, countsDown: true)
        } else {
            Text("0:00")
        }
    }
}

private struct CountdownHeaderCard: View {
    let nextTitle: String
    let nextStartDate: Date?
    let countdownStartDate: Date?
    let theme: AppPalette
    @Environment(\.colorScheme) private var colorScheme

    private var displayScheme: ColorScheme {
        switch theme {
        case .light, .pop:
            return .light
        case .dark, .elegant:
            return .dark
        case .system:
            return colorScheme
        @unknown default:
            return colorScheme
        }
    }

    private func remainingSeconds(at currentDate: Date) -> Int? {
        guard let nextStartDate else { return nil }
        return max(0, Int(nextStartDate.timeIntervalSince(currentDate)))
    }

    var body: some View {
        let accent = AppColors.accent(palette: theme, environmentScheme: displayScheme)
        let primary = AppColors.textPrimary(palette: theme, environmentScheme: displayScheme)
        let background = AppColors.background(palette: theme, environmentScheme: displayScheme)
        VStack(alignment: .leading, spacing: 10) {
            Text(nextStartDate != nil ? "Next event in…" : "Today's Status")
                .font(.caption)
                .foregroundStyle(primary.opacity(0.6))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let nextStartDate {
                        CountdownText(
                            startDate: countdownStartDate ?? Date(),
                            targetDate: nextStartDate
                        )
                            .font(.system(size: 30,weight: .heavy, design: .rounded))
                            .foregroundStyle(primary.opacity(0.95))
                    } else {
                        Text("NO PLAN")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(primary.opacity(0.8))
                    }
                }

                if let nextStartDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(nextStartDate, style: .time)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primary.opacity(0.85))
                        Text(nextTitle)
                            .font(.caption)
                            .foregroundStyle(primary.opacity(0.65))
                            .lineLimit(2)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(primary.opacity(0.06))
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let seconds = remainingSeconds(at: .now), seconds <= 3600 {
                CountdownProgressBar(secondsRemaining: seconds, accent: accent)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(primary.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct CountdownProgressBar: View {
    let secondsRemaining: Int
    let accent: Color

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
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .foregroundColor(accent)
                    .frame(width: max(6, width * progress))
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(accent)
                            .frame(width: 5, height: 5)
                            .opacity(0.15)
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

extension MAMONAKULiveActivityAttributes {
    fileprivate static var preview: MAMONAKULiveActivityAttributes {
        MAMONAKULiveActivityAttributes(name: "World")
    }
}

extension MAMONAKULiveActivityAttributes.ContentState {
    fileprivate static var upcoming: MAMONAKULiveActivityAttributes.ContentState {
        MAMONAKULiveActivityAttributes.ContentState(
            nextTitle: "Wake up",
            nextStartDate: Date().addingTimeInterval(25 * 60),
            countdownStartDate: Date(),
            remainingTimeShort: "25:00"
        )
     }
}

#Preview("Lock Screen", as: .content, using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.upcoming
}

#Preview("Dynamic Island - Expanded", as: .dynamicIsland(.expanded), using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.upcoming
}

#Preview("Dynamic Island - Compact", as: .dynamicIsland(.compact), using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.upcoming
}

#Preview("Dynamic Island - Minimal", as: .dynamicIsland(.minimal), using: MAMONAKULiveActivityAttributes.preview) {
    MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.upcoming
}
