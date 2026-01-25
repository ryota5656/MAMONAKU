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
            VStack {
                Text("次の予定まで")
                    .font(.caption)
                if let startDate = context.state.nextStartDate {
                    CountdownText(targetDate: startDate)
                        .font(.headline.monospacedDigit())
                    Text("\(context.state.nextTitle) \(startDate, style: .time)")
                        .font(.caption2)
                } else {
                    Text("予定なし")
                        .font(.headline)
                }
            }
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)

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

extension MAMONAKULiveActivityAttributes {
    fileprivate static var preview: MAMONAKULiveActivityAttributes {
        MAMONAKULiveActivityAttributes(name: "World")
    }
}

extension MAMONAKULiveActivityAttributes.ContentState {
    fileprivate static var upcoming: MAMONAKULiveActivityAttributes.ContentState {
        MAMONAKULiveActivityAttributes.ContentState(
            nextTitle: "30分",
            nextStartDate: Date().addingTimeInterval(25 * 60)
        )
     }
     
    fileprivate static var none: MAMONAKULiveActivityAttributes.ContentState {
        MAMONAKULiveActivityAttributes.ContentState(
            nextTitle: "予定なし",
            nextStartDate: nil
        )
    }
}

#Preview("Notification", as: .content, using: MAMONAKULiveActivityAttributes.preview) {
   MAMONAKULiveActivityLiveActivity()
} contentStates: {
    MAMONAKULiveActivityAttributes.ContentState.upcoming
    MAMONAKULiveActivityAttributes.ContentState.none
}
