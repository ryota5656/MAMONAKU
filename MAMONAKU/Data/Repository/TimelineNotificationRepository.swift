import Foundation

/// 予定に連動するローカル通知（開始通知・バッファ通知）の登録と、通知の許可。
protocol TimelineNotificationRepository: AnyObject {
    /// 通知が許可されているか。
    func isAuthorized() async -> Bool

    /// 通知の許可が未決定なら許可ダイアログを出す。
    func requestAuthorizationIfNeeded() async

    /// 開始時刻ちょうどに届く「開始通知」を、現在の設定と予定で登録し直す。
    func rescheduleStartNotifications(items: [TimelineItem])

    /// 開始の数分前に届く「バッファ通知」を、現在の設定と予定で登録し直す。
    func rescheduleBufferNotifications(items: [TimelineItem])
}

extension TimelineNotificationRepository {
    /// 開始通知・バッファ通知の両方を登録し直す。
    func rescheduleAll(items: [TimelineItem]) {
        rescheduleStartNotifications(items: items)
        rescheduleBufferNotifications(items: items)
    }
}

/// 予定に連動するローカル通知の種類。
nonisolated enum TimelineNotificationKind: Sendable {
    /// 開始時刻ちょうどに届く通知
    case start
    /// 開始の数分前（バッファ分）に届く通知
    case buffer

    /// この種類の通知リクエスト ID の接頭辞。後ろに予定 ID が付く。
    var identifierPrefix: String {
        switch self {
        case .start: return "timeline.start.notification."
        case .buffer: return "timeline.buffer.notification."
        }
    }

    /// 登録済みリクエストがこの種類のものか（旧バージョンが登録した ID も含む）。
    func owns(identifier: String) -> Bool {
        switch self {
        case .start:
            return identifier.hasPrefix(identifierPrefix)
                || identifier.hasPrefix("liveActivity.start.notification.")
        case .buffer:
            return identifier.hasPrefix(identifierPrefix)
                || identifier == "liveActivity.soon.notification"
        }
    }
}

/// 登録するローカル通知 1 件分の内容。
nonisolated struct TimelineNotificationPlan: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let fireDate: Date
}

/// 予定一覧から、登録すべき通知を決めるルール。
nonisolated enum TimelineNotificationPlanner {
    /// iOS のローカル通知登録上限（64 件）に収めるための上限。
    static let maximumPlans = 60

    /// - Parameters:
    ///   - isPlusSubscriber: 無料プランでは開始通知を直近の 1 件だけにする。
    ///   - bufferMinutes: バッファ通知を開始の何分前に出すか（開始通知では使わない）。
    static func plans(
        kind: TimelineNotificationKind,
        items: [TimelineItem],
        now: Date,
        isPlusSubscriber: Bool,
        bufferMinutes: Int,
        calendar: Calendar = .current
    ) -> [TimelineNotificationPlan] {
        let leadTime: TimeInterval = kind == .buffer ? TimeInterval(bufferMinutes * 60) : 0
        let upcoming = items
            .compactMap { item -> (item: TimelineItem, fireDate: Date)? in
                guard !item.isAllDay, let startDate = item.startDate(calendar: calendar) else { return nil }
                let fireDate = startDate.addingTimeInterval(-leadTime)
                return fireDate > now ? (item, fireDate) : nil
            }
            .sorted { $0.fireDate < $1.fireDate }

        let limit = (kind == .start && !isPlusSubscriber) ? 1 : maximumPlans
        return upcoming.prefix(limit).map { entry in
            TimelineNotificationPlan(
                identifier: kind.identifierPrefix + entry.item.id.uuidString,
                title: title(for: kind),
                body: body(for: kind, itemTitle: entry.item.title),
                fireDate: entry.fireDate
            )
        }
    }

    private static func title(for kind: TimelineNotificationKind) -> String {
        switch kind {
        case .start: return "予定の開始時間です"
        case .buffer: return "まもなく開始"
        }
    }

    private static func body(for kind: TimelineNotificationKind, itemTitle: String) -> String {
        switch kind {
        case .start: return "「\(itemTitle)」を開始しましょう"
        case .buffer: return "まもなく「\(itemTitle)」です。準備をしましょう"
        }
    }
}
