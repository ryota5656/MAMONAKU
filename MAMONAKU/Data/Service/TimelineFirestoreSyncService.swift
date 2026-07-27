import FirebaseAuth
import FirebaseFirestore
import Foundation
import os.log

/// ローカル予定を Firestore へ反映する（完了 / 更新ボタン時のみ呼ぶ）。
/// Functions は schedules + rebuild コマンドを監視して Cloud Tasks を再登録する。
@MainActor
final class TimelineFirestoreSyncService {
    static let shared = TimelineFirestoreSyncService()

    private let logger = Logger(subsystem: "sairyo.MAMONAKU", category: "TimelineFirestoreSync")
    private lazy var db = Firestore.firestore()

    private init() {}

    /// 当日の Live Activity 対象予定を Firestore に全置換し、rebuild を要求する。
    func syncTodaySchedules(
        items: [TimelineItem],
        maxVisibleSlots: Int
    ) async throws {
        guard let uid = await resolveUID() else {
            throw SyncError.notAuthenticated
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let eligible = items.filter { item in
            guard !item.isAllDay,
                  let dropDate = item.dropDate,
                  item.startMinutes != nil
            else { return false }
            return calendar.isDate(dropDate, inSameDayAs: todayStart)
        }

        let schedulesRef = db.collection("users").document(uid).collection("schedules")
        let existing = try await schedulesRef.getDocuments()
        let eligibleIDs = Set(eligible.map { $0.id.uuidString })

        let batch = db.batch()

        for item in eligible {
            guard let startMinutes = item.startMinutes, let dropDate = item.dropDate else { continue }
            let dayStart = calendar.startOfDay(for: dropDate)
            guard let startDate = calendar.date(byAdding: .minute, value: startMinutes, to: dayStart) else { continue }
            let endDate = startDate.addingTimeInterval(TimeInterval(item.durationMinutes * 60))

            let ref = schedulesRef.document(item.id.uuidString)
            var data: [String: Any] = [
                "title": item.title,
                "durationMinutes": item.durationMinutes,
                "startMinutes": startMinutes,
                "dropDate": Timestamp(date: dayStart),
                "startDate": Timestamp(date: startDate),
                "endDate": Timestamp(date: endDate),
                "isCompleted": item.isCompleted,
                "priority": item.priority.rawValue,
                "isAllDay": item.isAllDay,
                "deleted": false,
                "updatedAt": FieldValue.serverTimestamp(),
            ]
            if let buffer = item.bufferMinutes {
                data["bufferMinutes"] = buffer
            } else {
                data["bufferMinutes"] = NSNull()
            }
            batch.setData(data, forDocument: ref, merge: true)
        }

        for doc in existing.documents where !eligibleIDs.contains(doc.documentID) {
            batch.setData(
                [
                    "deleted": true,
                    "updatedAt": FieldValue.serverTimestamp(),
                ],
                forDocument: doc.reference,
                merge: true
            )
        }

        let deviceId = LiveActivityPushService.shared.resolvedDeviceID()
        try await LiveActivityPushService.shared.waitForRequiredPushTokens(timeoutSeconds: 15)
        try await upsertDeviceTokens(
            uid: uid,
            deviceId: deviceId,
            maxVisibleSlots: maxVisibleSlots,
            batch: batch
        )

        let rebuildRef = db.collection("users").document(uid)
            .collection("liveActivityCommands")
            .document("rebuild")
        batch.setData(
            [
                "requestedAt": FieldValue.serverTimestamp(),
                "deviceId": deviceId,
                "maxVisibleSlots": maxVisibleSlots,
                "reason": "client_commit",
            ],
            forDocument: rebuildRef,
            merge: true
        )

        try await batch.commit()
        logger.info("Synced \(eligible.count, privacy: .public) schedules for uid=\(uid, privacy: .public)")
        print("[TimelineFirestoreSync] Synced \(eligible.count) schedules, rebuild requested (slots=\(maxVisibleSlots))")
    }

    private func upsertDeviceTokens(
        uid: String,
        deviceId: String,
        maxVisibleSlots: Int,
        batch: WriteBatch
    ) async throws {
        guard
            let fcmToken = LiveActivityPushService.shared.currentFCMToken,
            let liveActivityToken = LiveActivityPushService.shared.currentLiveActivityUpdateToken
        else {
            throw SyncError.missingPushTokens
        }
        let apnsTopic = LiveActivityPushService.apnsTopic
        // 無料は1・PLUSスタックは最大3。rotation 実行時にこの値が使われるため同期時点で書き込む。
        let clampedSlots = min(max(maxVisibleSlots, 1), 3)

        let deviceRef = db.collection("users").document(uid).collection("devices").document(deviceId)
        batch.setData(
            [
                "fcmToken": fcmToken,
                "liveActivityToken": liveActivityToken,
                "apnsTopic": apnsTopic,
                "maxVisibleSlots": clampedSlots,
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            forDocument: deviceRef,
            merge: true
        )

        let laDeviceRef = db.collection("liveActivityDevices").document(deviceId)
        batch.setData(
            [
                "firebaseUid": uid,
                "fcmToken": fcmToken,
                "liveActivityToken": liveActivityToken,
                "apnsTopic": apnsTopic,
                "maxVisibleSlots": clampedSlots,
                "updatedAt": FieldValue.serverTimestamp(),
            ],
            forDocument: laDeviceRef,
            merge: true
        )
        print("[TimelineFirestoreSync] Device tokens upserted (fcm=\(fcmToken.prefix(8))… la=\(liveActivityToken.prefix(8))… slots=\(clampedSlots))")
    }

    private func resolveUID() async -> String? {
        if let uid = FirebaseAnonymousAuthService.shared.currentUID {
            return uid
        }
        await FirebaseAnonymousAuthService.shared.bootstrap()
        return FirebaseAnonymousAuthService.shared.currentUID
    }

    enum SyncError: LocalizedError {
        case notAuthenticated
        case missingPushTokens

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Firebase 匿名認証が未完了です"
            case .missingPushTokens:
                return "プッシュトークンが未取得です"
            }
        }
    }
}
