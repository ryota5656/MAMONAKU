import Foundation

@MainActor
protocol SettingsDelegate: AnyObject {
    func settingsDidAppear(subscriptionManager: SubscriptionManager)
    func settingsOpenSubscriptionSheet()
    func settingsSelectTheme(_ theme: AppPalette)
    func settingsCanSelectTheme(_ theme: AppPalette) -> Bool
    func settingsIncrementBufferMinutes()
    func settingsDecrementBufferMinutes()
    func settingsOpenMailFeedback()
    func settingsOpenTerms()
    func settingsOpenPrivacyPolicy()
}
