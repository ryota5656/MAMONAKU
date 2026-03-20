import SwiftUI

@main
struct MAMONAKUApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
                .environmentObject(themeManager)
        }
    }
}
