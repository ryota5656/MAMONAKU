import ActivityKit
import Foundation
import os

/// Live Activity をサーバーから更新するために必要なトークン類（FCM / Live Activity update / push-to-start）と
/// 端末 ID を受け取り、App Group の UserDefaults に保持する。
@MainActor
final class LiveActivityPushTokenClient {
    static let apnsTopic = "sairyo.MAMONAKU.push-type.liveactivity"

    private let defaults: UserDefaults
    private let logger = AppLog.push
    private var pushToStartTask: Task<Void, Never>?
    private var updateTokenTask: Task<Void, Never>?
    private var latestUpdateToken: String?

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - トークンの監視

    /// push-to-start トークンの監視を始める（アプリ起動時に 1 回呼ぶ）。
    func startObserving() {
        pushToStartTask?.cancel()
        pushToStartTask = Task { [weak self] in
            await self?.observePushToStartTokens()
        }
    }

    func setFCMToken(_ token: String) {
        defaults.set(token, forKey: AppGroup.fcmTokenKey)
        logger.info("FCM token stored: \(AppLog.maskedToken(token), privacy: .public)")
    }

    /// 起動した Live Activity の update トークンと、OS 側での内容・状態の変化を監視する。
    func observeUpdateToken(for activity: Activity<MAMONAKULiveActivityAttributes>) {
        updateTokenTask?.cancel()
        updateTokenTask = Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                let token = Self.hexString(from: tokenData)
                self?.latestUpdateToken = token
                self?.defaults.set(token, forKey: AppGroup.liveActivityUpdateTokenKey)
                self?.logger.info(
                    "Live Activity update token received (activity=\(activity.id, privacy: .public)): \(AppLog.maskedToken(token), privacy: .public)"
                )
            }
        }
        observeContentUpdates(for: activity)
    }

    /// OS / リモート push による内容・状態の変化をログに残す（動作には影響しない）。
    func observeContentUpdates(for activity: Activity<MAMONAKULiveActivityAttributes>) {
        Task { [logger] in
            for await content in activity.contentUpdates {
                let titles = content.state.schedule.map(\.nextTitle).joined(separator: " → ")
                logger.info(
                    "Live Activity content updated by OS (activity=\(activity.id, privacy: .public), items=\(content.state.schedule.count, privacy: .public)): \(titles, privacy: .public)"
                )
            }
        }

        Task { [logger] in
            for await state in activity.activityStateUpdates {
                logger.info(
                    "Live Activity state changed (activity=\(activity.id, privacy: .public)): \(String(describing: state), privacy: .public)"
                )
            }
        }
    }

    // MARK: - 現在のトークン

    /// Firestore / APNs 同期に必要な FCM トークン。
    var currentFCMToken: String? {
        nonEmptyString(forKey: AppGroup.fcmTokenKey)
    }

    /// Live Activity update 用 APNs トークン。
    var currentLiveActivityUpdateToken: String? {
        if let latestUpdateToken, !latestUpdateToken.isEmpty {
            return latestUpdateToken
        }
        return nonEmptyString(forKey: AppGroup.liveActivityUpdateTokenKey)
    }

    var hasRequiredPushTokens: Bool {
        currentFCMToken != nil && currentLiveActivityUpdateToken != nil
    }

    /// 新規 Live Activity 作成時に古い update トークンを捨て、再取得を待つ。
    func invalidateCachedLiveActivityUpdateToken() {
        latestUpdateToken = nil
        defaults.removeObject(forKey: AppGroup.liveActivityUpdateTokenKey)
        logger.info("Cached Live Activity update token invalidated")
    }

    /// FCM + Live Activity update トークンが揃うまで待つ。
    func waitForRequiredPushTokens(timeoutSeconds: TimeInterval = 15) async throws {
        if hasRequiredPushTokens { return }

        logger.info("Waiting for push tokens (timeout=\(Int(timeoutSeconds), privacy: .public)s)")
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if hasRequiredPushTokens { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        throw TokenWaitError.timedOut(
            missingFCM: currentFCMToken == nil,
            missingLiveActivity: currentLiveActivityUpdateToken == nil
        )
    }

    enum TokenWaitError: LocalizedError {
        case timedOut(missingFCM: Bool, missingLiveActivity: Bool)

        var errorDescription: String? {
            switch self {
            case let .timedOut(missingFCM, missingLiveActivity):
                var parts: [String] = []
                if missingFCM { parts.append("FCM") }
                if missingLiveActivity { parts.append("Live Activity update") }
                let label = parts.isEmpty ? "unknown" : parts.joined(separator: " / ")
                return "プッシュトークンの取得がタイムアウトしました（欠如: \(label)）"
            }
        }
    }

    // MARK: - 端末 ID

    /// App Group に永続化された deviceId（無ければ生成）。
    func resolvedDeviceID() -> String {
        if let existing = nonEmptyString(forKey: AppGroup.liveActivityDeviceIdKey) {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: AppGroup.liveActivityDeviceIdKey)
        return created
    }

    // MARK: - Private

    private func observePushToStartTokens() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities are disabled on this device.")
            return
        }

        for await tokenData in Activity<MAMONAKULiveActivityAttributes>.pushToStartTokenUpdates {
            let token = Self.hexString(from: tokenData)
            defaults.set(token, forKey: AppGroup.liveActivityPushToStartTokenKey)
            logger.info(
                "Live Activity push-to-start token: \(AppLog.tokenForManualTesting(token), privacy: .public) topic=\(Self.apnsTopic, privacy: .public)"
            )
        }
    }

    private func nonEmptyString(forKey key: String) -> String? {
        guard let value = defaults.string(forKey: key), !value.isEmpty else { return nil }
        return value
    }

    private static func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
