import FirebaseAuth
import Foundation
import os.log

/// ユーザーにログイン画面を出さず、匿名 Firebase ユーザーを裏で発行する。
/// 将来の Sign in with Apple 等とリンクするための土台。
@MainActor
final class FirebaseAnonymousAuthService {
    static let shared = FirebaseAnonymousAuthService()

    private let logger = Logger(subsystem: "sairyo.MAMONAKU", category: "FirebaseAuth")
    private lazy var auth = Auth.auth()

    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id)
    }

    private init() {}

    /// `FirebaseApp.configure()` の後に呼ぶ。
    func bootstrap() async {
        if let user = auth.currentUser {
            persistUID(user.uid)
            print("[FirebaseAuth] Existing anonymous user uid=\(user.uid)")
            await LiveActivityPushService.shared.retryPendingScheduleSyncIfNeeded()
            return
        }

        do {
            let result = try await auth.signInAnonymously()
            persistUID(result.user.uid)
            logger.info("Anonymous sign-in succeeded (uid=\(result.user.uid, privacy: .public))")
            print("[FirebaseAuth] Anonymous sign-in succeeded uid=\(result.user.uid)")
            await LiveActivityPushService.shared.retryPendingScheduleSyncIfNeeded()
        } catch {
            logger.error("Anonymous sign-in failed: \(error.localizedDescription, privacy: .public)")
            print("[FirebaseAuth] Anonymous sign-in failed: \(error.localizedDescription)")
        }
    }

    var currentUID: String? {
        auth.currentUser?.uid ?? appGroupDefaults?.string(forKey: AppGroup.firebaseUidKey)
    }

    func idToken(forceRefresh: Bool = false) async -> String? {
        if auth.currentUser == nil {
            await bootstrap()
        }
        guard let user = auth.currentUser else { return nil }
        do {
            return try await user.getIDToken(forcingRefresh: forceRefresh)
        } catch {
            logger.error("Failed to fetch ID token: \(error.localizedDescription, privacy: .public)")
            print("[FirebaseAuth] Failed to fetch ID token: \(error.localizedDescription)")
            return nil
        }
    }

    private func persistUID(_ uid: String) {
        appGroupDefaults?.set(uid, forKey: AppGroup.firebaseUidKey)
    }
}
