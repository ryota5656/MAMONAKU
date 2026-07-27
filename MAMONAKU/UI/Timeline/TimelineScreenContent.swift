import SwiftUI
import UIKit

/// タイムライン画面のレイアウト本体。ViewState と Delegate を受け取り UI 描画に専念する。
struct TimelineScreenContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let state: TimelineViewState
    @ObservedObject var viewModel: TimelineViewModel
    let delegate: TimelineDelegate?

    var body: some View {
        ZStack(alignment: .top) {
            headerSection
            whiteSheetSection
        }
        .overlay(alignment: .top) { tutorialTopOverlay }
//        .overlay(alignment: .top) { liveActivityPendingBanner }
        .overlay { liveActivityLoadingOverlay }
//        .overlay(alignment: .bottomLeading) { leftBottomOverlay }
//        .overlay(alignment: .bottomTrailing) { rightBottomOverlay }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var headerSection: some View {
        CountdownHeaderView(items: viewModel.items)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: HeaderHeightKey.self, value: proxy.size.height)
                }
            )
    }

    private var whiteSheetSection: some View {
        WhiteSheetView(
            viewModel: viewModel,
            sheetHeight: Binding(
                get: { viewModel.state.sheetHeight },
                set: { viewModel.state.sheetHeight = $0 }
            ),
            isSettingsHighlighted: false,
            onOpenSettings: {
                delegate?.timelineOpenSettings()
            }
        )
        .offset(y: state.isHeaderExpanded ? (state.headerHeight ) : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.isHeaderExpanded)
    }

    @ViewBuilder
    private var tutorialTopOverlay: some View {
        if let tutorialStep = state.tutorialStep {
            TutorialOverlayView(step: tutorialStep, onAdvance: {
                delegate?.timelineAdvanceTutorialStep()
            })
            .padding(.top, tutorialStep == .confirmCountdown ? 150 : 14)
            .padding(.horizontal, 16)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: tutorialStep)
        }
    }

    @ViewBuilder
    private var liveActivityPendingBanner: some View {
        if state.isLiveActivitySyncPending, state.tutorialStep == nil {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise.circle.fill")
                Text("ロック画面の予定が未反映です。＋を長押し→上にスライドで更新")
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme))
            )
            .padding(.top, 8)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var liveActivityLoadingOverlay: some View {
        if state.isLiveActivityRefreshing {
            ZStack {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Live Activityを更新中…")
                        .font(.footnote.weight(.semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemBackground))
                )
            }
        }
    }

    private var leftBottomOverlay: some View {
        Group {
            let primary = AppColors.primary(palette: themeManager.theme, environmentScheme: colorScheme)
            let onAccent = AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme)
            if viewModel.editMode.isEditing {
                ItemDropTarget(
                    onDrop: { viewModel.deleteItem(id: $0) },
                    onDragEntered: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.prepare()
                        generator.impactOccurred()
                        viewModel.state.isDeleteButtonTargeted = true
                    },
                    onDragExited: { viewModel.state.isDeleteButtonTargeted = false }
                )
                .frame(width: 44, height: 44)
                .zIndex(1)
                .overlay(alignment: .center) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 35))
                        .foregroundStyle(primary)
                        .shadow(color: Color.primary.opacity(0.2), radius: 6, x: 0, y: 3)
                        .scaleEffect(state.isDeleteButtonTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: state.isDeleteButtonTargeted)
                        .allowsHitTesting(false)
                }
            } else {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        delegate?.timelineToggleHeaderExpanded()
                    }
                } label: {
                    Image(systemName: state.isHeaderExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                        .font(.system(size: 35))
                        .foregroundStyle(primary)
                        .shadow(color: onAccent.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                .frame(width: 44, height: 44)
            }
        }
        .padding(.leading, 30)
        .padding(.bottom, 20)
    }

    private var rightBottomOverlay: some View {
        ZStack {
            let primary = AppColors.primary(palette: themeManager.theme, environmentScheme: colorScheme)
            let onAccent = AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme)
            if delegate?.timelineIsRadialMenuEnabled() == true, state.isRadialMenuVisible {
                radialMenu(primary: primary, onAccent: onAccent)
            }

            if viewModel.editMode.isEditing {
                ItemDropTarget(
                    onDrop: { viewModel.returnItemToStock(id: $0) },
                    onDragEntered: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.prepare()
                        generator.impactOccurred()
                        viewModel.state.isReturnToStockTargeted = true
                    },
                    onDragExited: { viewModel.state.isReturnToStockTargeted = false }
                )
                .frame(width: 35, height: 35)
                .zIndex(1)
                .overlay(alignment: .center) {
                    ZStack {
                        Circle()
                            .foregroundStyle(primary)
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(onAccent)
                            .shadow(color: Color.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .frame(width: 35, height: 35)
                    .scaleEffect(state.isReturnToStockTargeted ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: state.isReturnToStockTargeted)
                    .allowsHitTesting(false)
                }
            }

            if !viewModel.editMode.isEditing {
                plusButton(primary: primary, onAccent: onAccent)
            }
        }
        .padding(.trailing, 30)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func plusButton(primary: Color, onAccent: Color) -> some View {
        let radialEnabled = delegate?.timelineIsRadialMenuEnabled() == true
        ZStack {
            Circle()
                .foregroundStyle(primary)
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(onAccent)
                .shadow(color: Color.primary.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .frame(width: 35, height: 35)
        .overlay(alignment: .topTrailing) {
            if state.isLiveActivitySyncPending, state.tutorialStep == nil {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 9, height: 9)
                    .offset(x: 2, y: -2)
            }
        }
        .overlay {
            if state.tutorialStep == .confirmLiveActivity {
                Circle()
                    .stroke(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme), lineWidth: 3)
                    .scaleEffect(state.tutorialPulse ? 1.35 : 1.05)
                    .opacity(state.tutorialPulse ? 0.2 : 0.9)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: state.tutorialPulse)
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            delegate?.timelineOpenTaskSheet()
        }
        .applyIf(radialEnabled) { view in
            view.gesture(radialDragGesture)
        }
    }

    private var radialDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !viewModel.state.isRadialMenuVisible {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        viewModel.state.isRadialMenuVisible = true
                        viewModel.state.radialSelection = nil
                    }
                }
                let selection = delegate?.timelineRadialAction(at: value.location, in: CGSize(width: 52, height: 52))
                viewModel.state.radialSelection = selection
                if selection != nil, selection != viewModel.state.lastHapticSelection {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.prepare()
                    generator.impactOccurred()
                    viewModel.state.lastHapticSelection = selection
                }
            }
            .onEnded { _ in
                if viewModel.state.isRadialMenuVisible, let selection = viewModel.state.radialSelection {
                    delegate?.timelineTriggerRadialAction(selection)
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    viewModel.state.isRadialMenuVisible = false
                    viewModel.state.radialSelection = nil
                    viewModel.state.lastHapticSelection = nil
                }
            }
    }

    private func radialMenu(primary: Color, onAccent: Color) -> some View {
        ZStack {
            ForEach(TimelineRadialAction.allCases, id: \.self) { action in
                Circle()
                    .fill(state.radialSelection == action ? primary : primary.opacity(0.6))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: action.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(onAccent)
                    )
                    .onTapGesture {
                        delegate?.timelineTriggerRadialAction(action)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            viewModel.state.isRadialMenuVisible = false
                            viewModel.state.radialSelection = nil
                        }
                    }
                    .offset(action.offset)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}

private extension View {
    @ViewBuilder
    func applyIf(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Previews / Mock

final class PreviewTimelineDelegate: TimelineDelegate {
    func timelineDidAppear() {}
    func timelineDidOpenCreateSheet() {}
    func timelineItemsDidChange(hasPlacedTutorialTaskAfterNow: () -> Bool) {}
    func timelineDropPreviewDidChange(previewExists: Bool) {}
    func timelineToggleHeaderExpanded() {}
    func timelineOpenTaskSheet() {}
    func timelineOpenSettings() {}
    func timelineAdvanceTutorialStep() {}
    func timelineRefreshLiveActivityManually() async {}
    func timelineRadialAction(at location: CGPoint, in size: CGSize) -> TimelineRadialAction? { nil }
    func timelineIsRadialMenuEnabled() -> Bool { true }
    func timelineTriggerRadialAction(_ action: TimelineRadialAction) {}
}

#Preview("タイムライン（データあり）") {
    let viewModel = TimelineViewModel(
        initialItems: [
            TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 17 * 60, dropDate: Date()),
            TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date())
        ],
        enablePolling: false
    )
    TimelineScreenContent(
        state: viewModel.state,
        viewModel: viewModel,
        delegate: viewModel
    )
    .environmentObject(ThemeManager())
}

#Preview("チュートリアル表示") {
    TimelineScreenContent(
        state: TimelineViewState(tutorialStep: .touchStock),
        viewModel: TimelineViewModel(initialItems: [], enablePolling: false),
        delegate: PreviewTimelineDelegate()
    )
    .environmentObject(ThemeManager())
}
