import Foundation
import os

/// 用途別のロガー。`print` の代わりに使い、Console.app でもカテゴリで絞り込めるようにする。
nonisolated enum AppLog {
    private static let subsystem = "sairyo.MAMONAKU"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let auth = Logger(subsystem: subsystem, category: "FirebaseAuth")
    static let push = Logger(subsystem: subsystem, category: "Push")
    static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")
    static let scheduleSync = Logger(subsystem: subsystem, category: "ScheduleSync")
    static let storage = Logger(subsystem: subsystem, category: "Storage")

    /// トークンを先頭 8 文字と末尾 4 文字だけにしたログ用表記。
    static func maskedToken(_ token: String) -> String {
        guard token.count > 16 else { return token }
        return "\(token.prefix(8))…\(token.suffix(4)) (\(token.count) chars)"
    }

    /// 手動のプッシュ検証でコピーするトークン用の表記。DEBUG のみ全文、それ以外はマスクする。
    static func tokenForManualTesting(_ token: String) -> String {
        #if DEBUG
        return token
        #else
        return maskedToken(token)
        #endif
    }
}
