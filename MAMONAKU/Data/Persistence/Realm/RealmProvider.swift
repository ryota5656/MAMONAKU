import Foundation
import RealmSwift
import os

/// Realm の構成（保存先・スキーマバージョン）を持ち、Realm を開く。
nonisolated final class RealmProvider {
    static let schemaVersion: UInt64 = 5

    let configuration: Realm.Configuration

    /// - Parameter appGroupID: Realm ファイルを置く App Group。コンテナが取得できない場合は Realm 既定の場所を使う。
    init(appGroupID: String = AppGroup.id) {
        // スキーマ 2〜5 はプロパティ追加のみ（eventIdentifier 等 / isCompleted / priority / isAllDay）で、
        // Realm の自動マイグレーションが既定値を補うため、マイグレーション処理は空でよい。
        var configuration = Realm.Configuration(
            schemaVersion: Self.schemaVersion,
            migrationBlock: { _, _ in }
        )
        // fileURL に nil を入れると Realm が開けずクラッシュするため、取得できたときだけ上書きする。
        if let realmURL = Self.realmFileURL(appGroupID: appGroupID) {
            configuration.fileURL = realmURL
        } else {
            AppLog.storage.error("App Group container is unavailable; using the default Realm location")
        }
        self.configuration = configuration
    }

    func makeRealm() -> Realm {
        (try? Realm(configuration: configuration)) ?? (try! Realm())
    }

    private static func realmFileURL(appGroupID: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("MAMONAKU.realm")
    }
}
