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
    static let cloudFunctionsBaseURL = "https://us-central1-mamonaku-stg.cloudfunctions.net"
    #else
    static let name: Name = .prod
    static let firebaseProjectID = "mamonaku-98306"
    static let cloudFunctionsBaseURL = "https://us-central1-mamonaku-98306.cloudfunctions.net"
    #endif

    static var isStaging: Bool { name == .stg }

    static func cloudFunctionURL(_ functionName: String) -> String {
        "\(cloudFunctionsBaseURL)/\(functionName)"
    }
}
