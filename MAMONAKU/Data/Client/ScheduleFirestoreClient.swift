import FirebaseFirestore
import Foundation
import os

/// ローカル予定を Firestore へ反映する。
/// Functions は当日分だけを Live Activity に使い、それ以外の日は schedules に残る。
@MainActor
final class ScheduleFirestoreClient {
    private let authClient: FirebaseAuthClient
    private let pushTokenClient: LiveActivityPushTokenClient
    private let logger = AppLog.scheduleSync
    /// `FirebaseApp.configure()` 後に初めて触るよう遅延させる。
    private lazy var db = Firestore.firestore()

    init(authClient: FirebaseAuthClient, pushTokenClient: LiveActivityPushTokenClient) {
        self.authClient = authClient
        self.pushTokenClient = pushTokenClient
    }

    /// 配置済みの予定を、日を限らず Firestore に全置換する。
    /// `requestsRebuild` のときだけ Live Activity の組み直しも要求する。
    func syncSchedules(
        items: [TimelineItem],
        maxVisibleSlots: Int,
        requestsRebuild: Bool
    ) async throws {
        guard let uid = await resolveUID() else {
            throw SyncError.notAuthenticated
        }

        let calendar = Calendar.current
        let eligible = items.filter { item in
            !item.isAllDay && item.dropDate != nil && item.startMinutes != nil
        }

        let schedulesRef = db.collection("users").document(uid).collection("schedules")
        let existing = try await schedulesRef.getDocuments()
        let eligibleIDs = Set(eligible.map { $0.id.uuidString })

        var writes: [(ref: DocumentReference, data: [String: Any])] = []

        for item in eligible {
            guard let startMinutes = item.startMinutes, let dropDate = item.dropDate else { continue }
            let dayStart = calendar.startOfDay(for: dropDate)
            guard let startDate = calendar.date(byAdding: .minute, value: startMinutes, to: dayStart) else { continue }
            let endDate = startDate.addingTimeInterval(TimeInterval(item.durationMinutes * 60))

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
            if let routineID = item.routineID {
                data["routineID"] = routineID.uuidString
            } else {
                data["routineID"] = NSNull()
            }
            if let buffer = item.bufferMinutes {
                data["bufferMinutes"] = buffer
            } else {
                data["bufferMinutes"] = NSNull()
            }
            writes.append((schedulesRef.document(item.id.uuidString), data))
        }

        for doc in existing.documents where !eligibleIDs.contains(doc.documentID) {
            writes.append((
                doc.reference,
                [
                    "deleted": true,
                    "updatedAt": FieldValue.serverTimestamp(),
                ]
            ))
        }

        try await commit(writes)
        logger.info("Synced \(eligible.count, privacy: .public) schedules for uid=\(uid, privacy: .public)")

        guard requestsRebuild else { return }
        do {
            try await pushTokenClient.waitForRequiredPushTokens(timeoutSeconds: 15)
            let batch = db.batch()
            let deviceId = pushTokenClient.resolvedDeviceID()
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
        } catch {
            logger.warning("Device/rebuild sync skipped — schedules are already committed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Firestore の1バッチ上限（500）を超えないよう分けて書く。
    private func commit(_ writes: [(ref: DocumentReference, data: [String: Any])]) async throws {
        let chunkSize = 450
        var index = 0
        while index < writes.count {
            let batch = db.batch()
            let end = min(index + chunkSize, writes.count)
            for write in writes[index..<end] {
                batch.setData(write.data, forDocument: write.ref, merge: true)
            }
            try await batch.commit()
            index = end
        }
    }

    private func upsertDeviceTokens(
        uid: String,
        deviceId: String,
        maxVisibleSlots: Int,
        batch: WriteBatch
    ) async throws {
        guard
            let fcmToken = pushTokenClient.currentFCMToken,
            let liveActivityToken = pushTokenClient.currentLiveActivityUpdateToken
        else {
            throw SyncError.missingPushTokens
        }
        let apnsTopic = LiveActivityPushTokenClient.apnsTopic
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
        logger.info("Device tokens upserted (fcm=\(fcmToken.prefix(8), privacy: .public)… la=\(liveActivityToken.prefix(8), privacy: .public)… slots=\(clampedSlots, privacy: .public))")
    }

    private func resolveUID() async -> String? {
        if let uid = authClient.currentUID {
            return uid
        }
        await authClient.bootstrap()
        return authClient.currentUID
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
