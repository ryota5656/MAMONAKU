import FirebaseAnalytics
import Foundation

/// Google Analytics for Firebase への計測を集約する。
enum AnalyticsService {
    enum Screen {
        static let timeline = "timeline"
        static let settings = "settings"
        static let onboarding = "onboarding"
        static let subscription = "subscription"
    }

    enum Event {
        static let onboardingComplete = "onboarding_complete"
        static let firstRunComplete = "first_run_complete"
        static let taskCreate = "task_create"
        static let taskComplete = "task_complete"
        static let taskDelete = "task_delete"
        static let liveActivityRefresh = "live_activity_refresh"
        static let subscriptionPurchase = "subscription_purchase"
        static let tabSelect = "tab_select"
    }

    enum Param {
        static let placement = "placement"
        static let durationMinutes = "duration_minutes"
        static let priority = "priority"
        static let tab = "tab"
        static let productId = "product_id"
        static let success = "success"
        static let skipped = "skipped"
    }

    static func setUserID(_ userID: String?) {
        Analytics.setUserID(userID)
    }

    static func logScreen(_ name: String, class screenClass: String = "View") {
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: name,
                AnalyticsParameterScreenClass: screenClass
            ]
        )
    }

    static func log(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }

    static func logTaskCreate(placement: String, durationMinutes: Int, priority: String) {
        log(
            Event.taskCreate,
            parameters: [
                Param.placement: placement,
                Param.durationMinutes: durationMinutes,
                Param.priority: priority
            ]
        )
    }

    static func logTabSelect(_ tab: String) {
        log(Event.tabSelect, parameters: [Param.tab: tab])
    }
}
