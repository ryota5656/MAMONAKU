import FirebaseAuth
import Foundation
import os

/// ユーザーにログイン画面を出さず、匿名 Firebase ユーザーを裏で発行する。
/// 将来の Sign in with Apple 等とリンクするための土台。
@MainActor
final class FirebaseAuthClient {
    private let defaults: UserDefaults
    private let logger = AppLog.auth
    /// `FirebaseApp.configure()` 後に初めて触るよう遅延させる。
    private lazy var auth = Auth.auth()

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// 匿名ユーザーがいなければ発行する。`FirebaseApp.configure()` の後に呼ぶ。
    func bootstrap() async {
        if let user = auth.currentUser {
            didResolveUser(uid: user.uid)
            logger.info("Existing anonymous user (uid=\(user.uid, privacy: .public))")
            return
        }

        do {
            let result = try await auth.signInAnonymously()
            didResolveUser(uid: result.user.uid)
            logger.info("Anonymous sign-in succeeded (uid=\(result.user.uid, privacy: .public))")
        } catch {
            logger.error("Anonymous sign-in failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// サインイン済みユーザーの uid。未サインインのときは前回保存した uid を返す。
    var currentUID: String? {
        auth.currentUser?.uid ?? defaults.string(forKey: AppGroup.firebaseUidKey)
    }

    private func didResolveUser(uid: String) {
        defaults.set(uid, forKey: AppGroup.firebaseUidKey)
        AnalyticsClient.setUserID(uid)
    }
}
