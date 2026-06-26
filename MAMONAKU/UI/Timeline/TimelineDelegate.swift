import Foundation

@MainActor
protocol TimelineDelegate: AnyObject {
    func timelineDidAppear(ensureTutorialTask: () -> Void)
    func timelineItemsDidChange(hasPlacedTutorialTaskAfterNow: () -> Bool)
    func timelineDropPreviewDidChange(previewExists: Bool)
    func timelineToggleHeaderExpanded()
    func timelineOpenTaskSheet()
    func timelineOpenSettings()
    func timelineAdvanceTutorialStep()
    func timelineRefreshLiveActivityManually() async
    func timelineRadialAction(at location: CGPoint, in size: CGSize) -> TimelineRadialAction?
    func timelineIsRadialMenuEnabled() -> Bool
    func timelineTriggerRadialAction(_ action: TimelineRadialAction)
}
