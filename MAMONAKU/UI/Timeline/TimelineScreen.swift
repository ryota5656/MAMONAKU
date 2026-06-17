import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct TimelineScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = TimelineViewModel()

    init() {
        _viewModel = StateObject(wrappedValue: TimelineViewModel())
    }

    init(items: [TimelineItem]) {
        _viewModel = StateObject(
            wrappedValue: TimelineViewModel(
                initialItems: items,
                enablePolling: false
            )
        )
    }

    var body: some View {
        let uiState = viewModel.screen
        ZStack(alignment: .top) {
            headerSection
            whiteSheetSection
        }
        .overlay(alignment: .top) { tutorialTopOverlay }
        .overlay { liveActivityLoadingOverlay }
        .sheet(isPresented: Binding(get: { uiState.isTaskSheetPresented }, set: { viewModel.screen.isTaskSheetPresented = $0 })) { taskSheetContent }
        .onChange(of: viewModel.dropPreview) { _, preview in
            print("👉アイテムがタイムラインでドラッグされた")
            viewModel.screenOnDropPreviewChanged(previewExists: preview != nil)
        }
        .overlay(alignment: .bottomLeading) { leftBottomOverlay }
        .overlay(alignment: .bottomTrailing) { rightBottomOverlay }
        .onPreferenceChange(HeaderHeightKey.self) { value in
            viewModel.screen.headerHeight = value
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: Binding(get: { uiState.isSettingsPresented }, set: { viewModel.screen.isSettingsPresented = $0 })) {
            SettingsView()
        }
        .onAppear {
            viewModel.screenOnAppear {
                ensureTutorialTaskExists()
            }
        }
        .onChange(of: viewModel.items) { _, _ in
            viewModel.screenOnItemsChanged {
                hasPlacedTutorialTaskAfterNow()
            }
        }
    }

    private var headerSection: some View {
        CountdownHeaderView(
            items: viewModel.items,
        )
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
                get: { viewModel.screen.sheetHeight },
                set: { viewModel.screen.sheetHeight = $0 }
            ),
            isSettingsHighlighted: viewModel.screen.tutorialStep == .explainSettingsAndSubscription,
            onOpenSettings: {
                viewModel.screenOpenSettings()
            }
        )
        .offset(y: viewModel.screen.isHeaderExpanded ? (viewModel.screen.headerHeight + 12) : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.screen.isHeaderExpanded)
    }

    @ViewBuilder
    private var tutorialTopOverlay: some View {
        if let tutorialStep = viewModel.screen.tutorialStep {
            TutorialOverlayView(step: tutorialStep, onAdvance: viewModel.screenAdvanceTutorialStep)
                .padding(.top, tutorialStep == .confirmCountdown ? 150 : 14)
                .padding(.horizontal, 16)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: tutorialStep)
        }
    }

    @ViewBuilder
    private var liveActivityLoadingOverlay: some View {
        if viewModel.screen.isLiveActivityRefreshing {
            ZStack {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Live Activityを作成中…")
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

    private var taskSheetContent: some View {
        TaskListSheetView(
            items: viewModel.items,
            isPresented: Binding(get: { viewModel.screen.isTaskSheetPresented }, set: { viewModel.screen.isTaskSheetPresented = $0 }),
            isDraggingTask: Binding(get: { viewModel.screen.isDraggingTask }, set: { viewModel.screen.isDraggingTask = $0 }),
            isSheetDropTargeted: Binding(get: { viewModel.screen.isSheetDropTargeted }, set: { viewModel.screen.isSheetDropTargeted = $0 }),
            dragItemID: $viewModel.dragItemID,
            isSheetExpanded: $viewModel.chipsExpanded,
            isSheetDraggable: Binding(get: { viewModel.screen.isTaskSheetDraggable }, set: { viewModel.screen.isTaskSheetDraggable = $0 }),
            onMove: { from, to in
                viewModel.moveTaskItems(from: from, to: to)
            },
            onAdd: { title, durationMinutes, priority in
                viewModel.addStockItem(title: title, durationMinutes: durationMinutes, priority: priority)
            },
            onDelete: { id in
                viewModel.deleteItem(id: id)
            },
            onUpdate: { id, title, durationMinutes, priority in
                viewModel.updateItemDetails(
                    id: id,
                    title: title,
                    durationMinutes: durationMinutes,
                    priority: priority
                )
            },
            heightForDuration: { viewModel.heightForDuration($0) },
            onAddDebugTask: { minutes in
                viewModel.addTestTask(
                    startDate: Date().addingTimeInterval(TimeInterval(minutes * 60)),
                    durationMinutes: 15
                )
            },
            isSubscribed: subscriptionManager.effectiveIsSubscribed
        )
        .presentationDetents(
            viewModel.screen.isTaskSheetDraggable ? [.fraction(0.45), .large] : [viewModel.screen.taskSheetDetent],
            selection: Binding(get: { viewModel.screen.taskSheetDetent }, set: { viewModel.screen.taskSheetDetent = $0 })
        )
        .presentationDragIndicator(viewModel.screen.isTaskSheetDraggable ? .visible : .hidden)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled(!viewModel.screen.isTaskSheetDraggable)
    }

    private var leftBottomOverlay: some View {
        AnyView(
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
                            viewModel.screen.isDeleteButtonTargeted = true
                        },
                        onDragExited: { viewModel.screen.isDeleteButtonTargeted = false }
                    )
                    .frame(width: 44, height: 44)
                    .zIndex(1)
                    .overlay(alignment: .center) {
                        ZStack {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 35))
                                .foregroundStyle(primary)
                                .shadow(color: Color.primary.opacity(0.2), radius: 6, x: 0, y: 3)
                        }
                        .scaleEffect(viewModel.screen.isDeleteButtonTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.screen.isDeleteButtonTargeted)
                        .allowsHitTesting(false)
                    }
                } else {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.screenToggleHeaderExpanded()
                        }
                    } label: {
                        Image(systemName: viewModel.screen.isHeaderExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                            .font(.system(size: 35))
                            .foregroundStyle(primary)
                            .shadow(color: onAccent.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    .frame(width: 44, height: 44)
                }
            }
            .padding(.leading, 30)
            .padding(.bottom, 20)
        )
    }

    private var rightBottomOverlay: some View {
        AnyView(
            ZStack {
                let primary = AppColors.primary(palette: themeManager.theme, environmentScheme: colorScheme)
                let onAccent = AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme)
                if viewModel.screenIsRadialMenuEnabled() && viewModel.screen.isRadialMenuVisible {
                    radialMenu
                }

                if viewModel.editMode.isEditing {
                    ItemDropTarget(
                        onDrop: { viewModel.returnItemToStock(id: $0) },
                        onDragEntered: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.prepare()
                            generator.impactOccurred()
                            viewModel.screen.isReturnToStockTargeted = true
                        },
                        onDragExited: { viewModel.screen.isReturnToStockTargeted = false }
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
                        .scaleEffect(viewModel.screen.isReturnToStockTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.screen.isReturnToStockTargeted)
                        .allowsHitTesting(false)
                    }
                }

                if !viewModel.editMode.isEditing {
                    if viewModel.screenIsRadialMenuEnabled() {
                        ZStack {
                            Circle()
                                .foregroundStyle(primary)
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(onAccent)
                                .shadow(color: Color.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .frame(width: 35, height: 35)
                        .overlay {
                            if viewModel.screen.tutorialStep == .openTaskList || viewModel.screen.tutorialStep == .explainLiveActivityFromPlus {
                                Circle()
                                    .stroke(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme), lineWidth: 3)
                                    .scaleEffect(viewModel.screen.tutorialPulse ? 1.35 : 1.05)
                                    .opacity(viewModel.screen.tutorialPulse ? 0.2 : 0.9)
                                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: viewModel.screen.tutorialPulse)
                                    .onAppear { viewModel.screen.tutorialPulse = true }
                            }
                        }
                        .contentShape(Circle())
                        .onTapGesture {
                            viewModel.screenOpenTaskSheet()
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !viewModel.screen.isRadialMenuVisible {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                            viewModel.screen.isRadialMenuVisible = true
                                            viewModel.screen.radialSelection = nil
                                        }
                                    }
                                    let selection = viewModel.screenRadialAction(at: value.location, in: CGSize(width: 52, height: 52))
                                    viewModel.screen.radialSelection = selection
                                    if selection != nil, selection != viewModel.screen.lastHapticSelection {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.prepare()
                                        generator.impactOccurred()
                                        viewModel.screen.lastHapticSelection = selection
                                    }
                                }
                                .onEnded { _ in
                                    if viewModel.screen.isRadialMenuVisible, let selection = viewModel.screen.radialSelection {
                                        trigger(action: selection)
                                    }
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        viewModel.screen.isRadialMenuVisible = false
                                        viewModel.screen.radialSelection = nil
                                        viewModel.screen.lastHapticSelection = nil
                                    }
                                }
                        )
                    } else {
                        ZStack {
                            Circle()
                                .foregroundStyle(primary)
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(onAccent)
                                .shadow(color: Color.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .frame(width: 35, height: 35)
                        .overlay {
                            if viewModel.screen.tutorialStep == .openTaskList || viewModel.screen.tutorialStep == .explainLiveActivityFromPlus {
                                Circle()
                                    .stroke(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme), lineWidth: 3)
                                    .scaleEffect(viewModel.screen.tutorialPulse ? 1.35 : 1.05)
                                    .opacity(viewModel.screen.tutorialPulse ? 0.2 : 0.9)
                                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: viewModel.screen.tutorialPulse)
                                    .onAppear { viewModel.screen.tutorialPulse = true }
                            }
                        }
                        .contentShape(Circle())
                        .onTapGesture {
                            viewModel.screenOpenTaskSheet()
                        }
                    }
                }
            }
            .padding(.trailing, 30)
            .padding(.bottom, 20)
        )
    }

    private func ensureTutorialTaskExists() {
        let tutorialTitle = "はじめてのタスク"
        let hasTutorialTask = viewModel.items.contains { $0.title == tutorialTitle }
        guard !hasTutorialTask else { return }
        viewModel.addStockItem(title: tutorialTitle, durationMinutes: 30, priority: .low)
    }

    private func hasPlacedTutorialTaskAfterNow() -> Bool {
        let nowMinutes = viewModel.minutesSinceMidnight(date: Date())
        return viewModel.items.contains {
            $0.title == "はじめてのタスク" &&
            $0.dropDate != nil &&
            ($0.startMinutes ?? -1) > nowMinutes
        }
    }

}

private extension TimelineScreen {
    var radialMenu: some View {
        let primary = AppColors.primary(palette: themeManager.theme, environmentScheme: colorScheme)
        let onAccent = AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme)
        return ZStack {
            ForEach(TimelineRadialAction.allCases, id: \.self) { action in
                Circle()
                    .fill(viewModel.screen.radialSelection == action ? primary : primary.opacity(0.6))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: action.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(onAccent)
                    )
                    .onTapGesture {
                        trigger(action: action)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            viewModel.screen.isRadialMenuVisible = false
                            viewModel.screen.radialSelection = nil
                        }
                    }
                    .offset(action.offset)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    func trigger(action: TimelineRadialAction) {
        switch action {
        case .settings:
            viewModel.screenOpenSettings()
        case .refreshLiveActivity:
            Task { await viewModel.screenRefreshLiveActivityManually() }
        }
    }
}

#Preview{
    ContentView()
        .environmentObject(SubscriptionManager())
        .environmentObject(ThemeManager())
}
#Preview("scheduleItemPreview"){
    ScheduleItemPreviewView(
        item: TimelineItem(title: "Preview", durationMinutes: 60, startMinutes: 120),
        showTimeRange: true
    )
    .frame(height: 100)
    .padding(20)
    .environmentObject(ThemeManager())
}


#Preview("timeline with items") {
    TimelineScreen(items: [
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 17 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date()),
        TimelineItem(title: "Breakfast", durationMinutes: 30, startMinutes: 4 * 60, dropDate: Date()),
        TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 5 * 60, dropDate: Date())
    ])
    .environmentObject(SubscriptionManager())
    .environmentObject(ThemeManager())
}

