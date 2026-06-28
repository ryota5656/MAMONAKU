//
//  RealmProvider.swift
//  MAMONAKU
//

import Foundation
import RealmSwift

final class RealmProvider {
    static let defaultAppGroupID = "group.sairyo.MAMONAKU"
    static let schemaVersion: UInt64 = 5

    let configuration: Realm.Configuration

    init(appGroupID: String = defaultAppGroupID) {
        let realmURL = Self.realmFileURL(appGroupID: appGroupID)
        if let realmURL {
            print("Realm file URL: \(realmURL)")
        } else {
            print("Realm file URL: nil (using default Realm configuration)")
        }

        configuration = Realm.Configuration(
            fileURL: realmURL,
            schemaVersion: Self.schemaVersion,
            migrationBlock: { _, oldSchemaVersion in
                if oldSchemaVersion < 2 {
                    // Automatic migration is sufficient for added properties.
                }
                if oldSchemaVersion < 3 {
                    // isCompleted added; default false is applied by Realm.
                }
                if oldSchemaVersion < 4 {
                    // priority added; default 1 (medium) is applied by Realm.
                }
                if oldSchemaVersion < 5 {
                    // isAllDay added; default false is applied by Realm.
                }
            }
        )
    }

    func makeRealm() -> Realm {
        (try? Realm(configuration: configuration)) ?? (try! Realm())
    }

    private static func realmFileURL(appGroupID: String) -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        return containerURL.appendingPathComponent("MAMONAKU.realm")
    }
}
