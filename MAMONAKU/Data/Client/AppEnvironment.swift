import Foundation

/// ビルド設定に応じた Firebase / バックエンド環境。
/// Debug → STG / Release（TestFlight・App Store）→ PROD
enum AppEnvironment {
    enum Name: String {
        case stg
        case prod
    }

    #if DEBUG
    static let name: Name = .stg
    static let firebaseProjectID = "mamonaku-stg"
    #else
    static let name: Name = .prod
    static let firebaseProjectID = "mamonaku-98306"
    #endif
}
