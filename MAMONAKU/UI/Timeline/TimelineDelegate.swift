import Foundation

@MainActor
protocol TimelineDelegate: AnyObject {
    func timelineDidAppear()
    func timelineDidOpenCreateSheet()
    func timelineItemsDidChange(hasPlacedTutorialTaskAfterNow: () -> Bool)
    func timelineDropPreviewDidChange(previewExists: Bool)
    func timelineToggleHeaderExpanded()
    func timelineOpenTaskSheet()
    func timelineOpenSettings()
    func timelineSkipTutorial()
    func timelineRefreshLiveActivityManually() async
    func timelineRadialAction(at location: CGPoint, in size: CGSize) -> TimelineRadialAction?
    func timelineIsRadialMenuEnabled() -> Bool
    func timelineTriggerRadialAction(_ action: TimelineRadialAction)
}
