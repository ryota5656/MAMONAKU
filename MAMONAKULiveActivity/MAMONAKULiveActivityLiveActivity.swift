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
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MAMONAKULiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration{
        ActivityConfiguration(for: MAMONAKULiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            CountdownHeaderCard(
                nextTitle: context.state.nextTitle,
                nextStartDate: context.state.nextStartDate
            )
            .environment(\.colorScheme, .light)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("次")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let startDate = context.state.nextStartDate {
                        CountdownText(targetDate: startDate)
                            .font(.caption2.monospacedDigit())
                    } else {
                        Text("--:--:--")
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let startDate = context.state.nextStartDate {
                        Text("\(context.state.nextTitle) \(startDate, style: .time)")
                    } else {
                        Text("予定なし")
                    }
                }
            } compactLeading: {
                Text("次")
            } compactTrailing: {
                if let startDate = context.state.nextStartDate {
                    CountdownText(targetDate: startDate)
                        .font(.caption2.monospacedDigit())
                } else {
                    Text("--:--")
                }
            } minimal: {
                if let startDate = context.state.nextStartDate {
                    CountdownText(targetDate: startDate)
                        .font(.caption2.monospacedDigit())
                } else {
                    Text("--:--")
                }
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

private struct CountdownText: View {
    let targetDate: Date

    var body: some View {
        // Text(timerInterval:pauseTime:countsDown:) を使ったカウントダウン
        let now = Date()
        let end = max(now, targetDate)
        return Text(timerInterval: now...end, pauseTime: nil, countsDown: true)
    }
}

private struct CountdownHeaderCard: View {
    let nextTitle: String
    let nextStartDate: Date?

    private var remainingSeconds: Int? {
        guard let nextStartDate else { return nil }
        return max(0, Int(nextStartDate.timeIntervalSinceNow))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next event in…")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let nextStartDate {
                        CountdownText(targetDate: nextStartDate)
                            .font(.system(size: 30,weight: .heavy, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.9))
                    }
                }

                if let nextStartDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(nextStartDate, style: .time)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.systemBackground)
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
            .frame(maxWidth: .infinity, alignment: .leading)


            if let seconds = remainingSeconds, seconds <= 3600 {
                CountdownProgressBar(secondsRemaining: seconds)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
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
                    .foregroundColor(AppColors.systemBackground)
                    .frame(width: max(6, width * progress))
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.black)
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
            nextStartDate: Date().addingTimeInterval(25 * 60)
        )
     }
}

#Preview("Notification", as: .content, using: MAMONAKULiveActivityAttributes.preview) {
   MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.upcoming
}
