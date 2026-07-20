import ActivityKit
import Foundation
import os.log

/// Live Activity の push token 監視と、Cloud Functions へのスケジュール同期。
@MainActor
final class LiveActivityPushService {
    static let shared = LiveActivityPushService()

    static let apnsTopic = "sairyo.MAMONAKU.push-type.liveactivity"
    static let attributesType = "MAMONAKULiveActivityAttributes"
    static let syncEndpoint = "https://us-central1-mamonaku-98306.cloudfunctions.net/syncLiveActivitySchedule"

    private let logger = Logger(subsystem: "sairyo.MAMONAKU", category: "LiveActivityPush")
    private var pushToStartTask: Task<Void, Never>?
    private var updateTokenTask: Task<Void, Never>?
    private var latestUpdateToken: String?
    private var pendingSync = false

    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id)
    }

    private init() {}

    func startObserving() {
        pushToStartTask?.cancel()
        pushToStartTask = Task { [weak self] in
            await self?.observePushToStartTokens()
        }
    }

    func setFCMToken(_ token: String) {
        appGroupDefaults?.set(token, forKey: AppGroup.fcmTokenKey)
        logger.info("FCM token stored: \(Self.tokenPreview(token), privacy: .public)")
        print("[LiveActivityPush] FCM token stored: \(Self.tokenPreview(token))")
        if pendingSync {
            logger.info("Pending schedule sync will retry now that FCM token is available")
            print("[LiveActivityPush] Pending schedule sync will retry (FCM token now available)")
            pendingSync = false
            Task { await flushPendingScheduleSync() }
        }
    }

    func observeUpdateToken(for activity: Activity<MAMONAKULiveActivityAttributes>) {
        updateTokenTask?.cancel()
        updateTokenTask = Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                let token = Self.hexString(from: tokenData)
                self?.latestUpdateToken = token
                self?.appGroupDefaults?.set(token, forKey: AppGroup.liveActivityUpdateTokenKey)
                self?.logger.info(
                    "Live Activity update token received (activity=\(activity.id, privacy: .public)): \(Self.tokenPreview(token), privacy: .public)"
                )
                print("[LiveActivityPush] Live Activity update token received (activity=\(activity.id))")
                print("[LiveActivityPush]   token: \(Self.tokenPreview(token))")
                await self?.flushPendingScheduleSync()
            }
        }
        observeContentUpdates(for: activity)
    }

    /// OS / リモート push による ContentState 変更を監視してログ出力する。
    func observeContentUpdates(for activity: Activity<MAMONAKULiveActivityAttributes>) {
        Task { [logger] in
            for await content in activity.contentUpdates {
                let titles = content.state.schedule.map(\.nextTitle).joined(separator: " → ")
                logger.info(
                    "Live Activity content updated by OS (activity=\(activity.id, privacy: .public)): \(titles, privacy: .public)"
                )
                print("[LiveActivityPush] Live Activity content updated by OS (activity=\(activity.id))")
                print("[LiveActivityPush]   schedule (\(content.state.schedule.count) items): \(titles)")
                print("[LiveActivityPush]   activityState: \(String(describing: activity.activityState))")
                if let staleDate = content.staleDate {
                    print("[LiveActivityPush]   staleDate: \(staleDate.formatted())")
                }
            }
        }

        Task { [logger] in
            for await state in activity.activityStateUpdates {
                logger.info(
                    "Live Activity state changed (activity=\(activity.id, privacy: .public)): \(String(describing: state), privacy: .public)"
                )
                print("[LiveActivityPush] Live Activity state changed (activity=\(activity.id)): \(state)")
            }
        }
    }

    func syncSchedule(rotations: [LiveActivityScheduleBuilder.Rotation]) async {
        logger.info("Schedule sync requested (rotations=\(rotations.count, privacy: .public))")
        print("[LiveActivityPush] Schedule sync requested (\(rotations.count) rotations)")
        appGroupDefaults?.set(encodeRotations(rotations), forKey: AppGroup.liveActivityPendingRotationsKey)
        await flushPendingScheduleSync()
    }

    /// 匿名認証完了後など、保留中のスケジュール同期を再試行する。
    func retryPendingScheduleSyncIfNeeded() async {
        guard appGroupDefaults?.data(forKey: AppGroup.liveActivityPendingRotationsKey) != nil else { return }
        await flushPendingScheduleSync()
    }

    private func flushPendingScheduleSync() async {
        guard
            let payloadData = appGroupDefaults?.data(forKey: AppGroup.liveActivityPendingRotationsKey),
            let rotations = try? JSONDecoder().decode([PersistedRotation].self, from: payloadData)
        else { return }

        guard let liveActivityToken = latestUpdateToken ?? appGroupDefaults?.string(forKey: AppGroup.liveActivityUpdateTokenKey),
              !liveActivityToken.isEmpty
        else {
            pendingSync = true
            logger.warning("Schedule sync deferred: Live Activity update token not yet available")
            print("[LiveActivityPush] Schedule sync deferred — waiting for Live Activity update token")
            return
        }

        guard let fcmToken = appGroupDefaults?.string(forKey: AppGroup.fcmTokenKey), !fcmToken.isEmpty else {
            pendingSync = true
            logger.warning("Schedule sync deferred: FCM token not yet available")
            print("[LiveActivityPush] Schedule sync deferred — waiting for FCM token")
            return
        }

        guard let firebaseUid = FirebaseAnonymousAuthService.shared.currentUID else {
            pendingSync = true
            logger.warning("Schedule sync deferred: Firebase anonymous uid not yet available")
            print("[LiveActivityPush] Schedule sync deferred — waiting for Firebase anonymous auth")
            return
        }

        guard let idToken = await FirebaseAnonymousAuthService.shared.idToken() else {
            pendingSync = true
            logger.warning("Schedule sync deferred: Firebase ID token not yet available")
            print("[LiveActivityPush] Schedule sync deferred — waiting for Firebase ID token")
            return
        }

        let deviceId = Self.deviceID(defaults: appGroupDefaults)
        let body: [String: Any] = [
            "deviceId": deviceId,
            "firebaseUid": firebaseUid,
            "idToken": idToken,
            "fcmToken": fcmToken,
            "liveActivityToken": liveActivityToken,
            "apnsTopic": Self.apnsTopic,
            "rotations": rotations.map { $0.asDictionary() },
        ]

        logger.info(
            "Sending schedule sync to Cloud Functions (deviceId=\(deviceId, privacy: .public), rotations=\(rotations.count, privacy: .public))"
        )
        print("[LiveActivityPush] ── Cloud Functions sync START ──")
        print("[LiveActivityPush]   endpoint: \(Self.syncEndpoint)")
        print("[LiveActivityPush]   deviceId: \(deviceId)")
        print("[LiveActivityPush]   firebaseUid: \(firebaseUid)")
        print("[LiveActivityPush]   fcmToken: \(Self.tokenPreview(fcmToken))")
        print("[LiveActivityPush]   liveActivityToken: \(Self.tokenPreview(liveActivityToken))")
        print("[LiveActivityPush]   apnsTopic: \(Self.apnsTopic)")
        print("[LiveActivityPush]   rotations: \(rotations.count)")
        for (index, rotation) in rotations.enumerated() {
            let titles = rotation.schedule.map(\.nextTitle).joined(separator: " → ")
            let switchAt = Date(timeIntervalSince1970: TimeInterval(rotation.switchAtUnix))
            print("[LiveActivityPush]     [\(index)] switchAt=\(switchAt.formatted()) reason=\(rotation.reason) end=\(rotation.shouldEndActivity) schedule=\(titles)")
        }

        guard let url = URL(string: Self.syncEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                appGroupDefaults?.removeObject(forKey: AppGroup.liveActivityPendingRotationsKey)
                pendingSync = false
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                logger.info(
                    "Cloud Functions sync succeeded (status=\(http.statusCode, privacy: .public), rotations=\(rotations.count, privacy: .public))"
                )
                print("[LiveActivityPush] ── Cloud Functions sync SUCCESS ──")
                print("[LiveActivityPush]   HTTP \(http.statusCode)")
                if !responseBody.isEmpty {
                    print("[LiveActivityPush]   response: \(responseBody)")
                }
            } else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                logger.error("Cloud Functions sync failed (status=\(status, privacy: .public))")
                print("[LiveActivityPush] ── Cloud Functions sync FAILED ──")
                print("[LiveActivityPush]   HTTP \(status)")
                if !responseBody.isEmpty {
                    print("[LiveActivityPush]   response: \(responseBody)")
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = json["errorMessage"] as? String {
                        print("[LiveActivityPush]   detail: \(detail)")
                    }
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let hint = json["hint"] as? String {
                        print("[LiveActivityPush]   hint: \(hint)")
                    }
                }
            }
        } catch {
            logger.error("Cloud Functions sync error: \(error.localizedDescription, privacy: .public)")
            print("[LiveActivityPush] ── Cloud Functions sync ERROR ──")
            print("[LiveActivityPush]   \(error.localizedDescription)")
        }
    }

    private func encodeRotations(_ rotations: [LiveActivityScheduleBuilder.Rotation]) -> Data {
        let persisted = rotations.map { rotation in
            PersistedRotation(
                switchAtUnix: Int(rotation.switchAt.timeIntervalSince1970),
                schedule: rotation.schedule,
                shouldEndActivity: rotation.shouldEndActivity,
                reason: rotation.reason
            )
        }
        return (try? JSONEncoder().encode(persisted)) ?? Data()
    }

    private func observePushToStartTokens() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities are disabled on this device.")
            print("[LiveActivityPush] Live Activities are disabled on this device.")
            return
        }

        for await tokenData in Activity<MAMONAKULiveActivityAttributes>.pushToStartTokenUpdates {
            let token = Self.hexString(from: tokenData)
            appGroupDefaults?.set(token, forKey: AppGroup.liveActivityPushToStartTokenKey)
            logger.info("Live Activity Push-to-Start Token: \(token, privacy: .public)")
            print("[LiveActivityPush] Push-to-Start Token: \(token)")
            print("[LiveActivityPush] APNs topic: \(Self.apnsTopic)")
        }
    }

    private static func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// ログ用にトークンをマスク（先頭8文字 + 末尾4文字のみ表示）
    private static func tokenPreview(_ token: String) -> String {
        guard token.count > 16 else { return token }
        let prefix = token.prefix(8)
        let suffix = token.suffix(4)
        return "\(prefix)…\(suffix) (\(token.count) chars)"
    }

    private static func deviceID(defaults: UserDefaults?) -> String {
        let key = AppGroup.liveActivityDeviceIdKey
        if let existing = defaults?.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        defaults?.set(created, forKey: key)
        return created
    }
}

private struct PersistedRotation: Codable {
    let switchAtUnix: Int
    let schedule: [ActivityTaskItem]
    let shouldEndActivity: Bool
    let reason: String

    func asDictionary() -> [String: Any] {
        let schedulePayload: [[String: Any]] = schedule.map { item in
            var dict: [String: Any] = [
                "nextTitle": item.nextTitle,
                "remainingTimeShort": item.remainingTimeShort,
            ]
            if let nextStartDate = item.nextStartDate {
                dict["nextStartDate"] = nextStartDate.timeIntervalSinceReferenceDate
            }
            if let nextEndDate = item.nextEndDate {
                dict["nextEndDate"] = nextEndDate.timeIntervalSinceReferenceDate
            }
            if let countdownStartDate = item.countdownStartDate {
                dict["countdownStartDate"] = countdownStartDate.timeIntervalSinceReferenceDate
            }
            if let bufferMinutes = item.bufferMinutes {
                dict["bufferMinutes"] = bufferMinutes
            }
            return dict
        }

        return [
            "switchAtUnix": switchAtUnix,
            "schedule": schedulePayload,
            "shouldEndActivity": shouldEndActivity,
            "reason": reason,
        ]
    }
}
