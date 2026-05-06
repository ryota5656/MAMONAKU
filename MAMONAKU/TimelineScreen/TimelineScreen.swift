import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct TimelineScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = TimelineViewModel()
    @State private var sheetHeight: CGFloat = 0
    @State private var isHeaderExpanded = true
    @State private var isTaskSheetPresented = false
    @State private var isDraggingTask = false
    @State private var isSheetDropTargeted = false
    @State private var isTaskSheetDraggable = true
    @State private var taskSheetDetent: PresentationDetent = .fraction(0.45)
    @State private var headerHeight: CGFloat = 0
    @State private var isRadialMenuVisible = false
    @State private var radialSelection: RadialAction? = nil
    @State private var lastHapticSelection: RadialAction? = nil
    @State private var isSettingsPresented = false
    @State private var isDeleteButtonTargeted = false
    @State private var isReturnToStockTargeted = false
    @State private var isLiveActivityRefreshing = false
    @AppStorage("tutorial.firstRun.completed") private var isFirstRunTutorialCompleted: Bool = false
    @State private var tutorialStep: TutorialStep? = nil
    @State private var tutorialPulse: Bool = false
    private let isRadialMenuEnabled = true
    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

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
        ZStack(alignment: .top) {
            headerSection
            whiteSheetSection
        }
        .overlay(alignment: .top) { tutorialTopOverlay }
        .overlay { liveActivityLoadingOverlay }
        .sheet(isPresented: $isTaskSheetPresented) { taskSheetContent }
        .onChange(of: viewModel.dropPreview) { _, preview in
            guard isTaskSheetPresented, isDraggingTask, preview != nil else { return }
            isDraggingTask = false
            isTaskSheetPresented = false
        }
        .overlay(alignment: .bottomLeading) { leftBottomOverlay }
        .overlay(alignment: .bottomTrailing) { rightBottomOverlay }
        .onPreferenceChange(HeaderHeightKey.self) { value in
            headerHeight = value
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .onAppear {
            startFirstRunTutorialIfNeeded()
        }
        .onChange(of: viewModel.items) { _, _ in
            if tutorialStep == .placeTaskAfterNow, hasPlacedTutorialTaskAfterNow() {
                tutorialStep = .confirmCountdown
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
//            if newPhase == .active {
//                Task {
//                    await viewModel.resetLiveActivity()
//                }
//            } else if newPhase == .inactive {
//                Task {
//                    await viewModel.startOrUpdateLiveActivity()
//                }
//            }
        }
    }

    private var headerSection: some View {
        CountdownHeaderView(
            items: viewModel.items,
            isExpanded: $isHeaderExpanded
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
            sheetHeight: $sheetHeight,
            isSettingsHighlighted: tutorialStep == .explainSettingsAndSubscription,
            onOpenSettings: {
                isSettingsPresented = true
            }
        )
        .offset(y: isHeaderExpanded ? (headerHeight + 12) : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isHeaderExpanded)
    }

    @ViewBuilder
    private var tutorialTopOverlay: some View {
        if let tutorialStep {
            tutorialOverlay(step: tutorialStep)
                .padding(.top, tutorialStep == .confirmCountdown ? 150 : 14)
                .padding(.horizontal, 16)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: tutorialStep)
        }
    }

    @ViewBuilder
    private var liveActivityLoadingOverlay: some View {
        if isLiveActivityRefreshing {
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
            isPresented: $isTaskSheetPresented,
            isDraggingTask: $isDraggingTask,
            isSheetDropTargeted: $isSheetDropTargeted,
            dragItemID: $viewModel.dragItemID,
            isSheetExpanded: $viewModel.chipsExpanded,
            isSheetDraggable: $isTaskSheetDraggable,
            onMove: { from, to in
                viewModel.moveTaskItems(from: from, to: to)
            },
            onAdd: { title, durationMinutes, priority in
                viewModel.addStockItem(title: title, durationMinutes: durationMinutes, priority: priority)
            },
            onDelete: { id in
                viewModel.deleteItem(id: id)
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
            isTaskSheetDraggable ? [.fraction(0.45), .large] : [taskSheetDetent],
            selection: $taskSheetDetent
        )
        .presentationDragIndicator(isTaskSheetDraggable ? .visible : .hidden)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled(!isTaskSheetDraggable)
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
                            isDeleteButtonTargeted = true
                        },
                        onDragExited: { isDeleteButtonTargeted = false }
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
                        .scaleEffect(isDeleteButtonTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDeleteButtonTargeted)
                        .allowsHitTesting(false)
                    }
                } else {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isHeaderExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isHeaderExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
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
                if isRadialMenuEnabled && isRadialMenuVisible {
                    radialMenu
                }

                if viewModel.editMode.isEditing {
                    ItemDropTarget(
                        onDrop: { viewModel.returnItemToStock(id: $0) },
                        onDragEntered: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.prepare()
                            generator.impactOccurred()
                            isReturnToStockTargeted = true
                        },
                        onDragExited: { isReturnToStockTargeted = false }
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
                        .scaleEffect(isReturnToStockTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isReturnToStockTargeted)
                        .allowsHitTesting(false)
                    }
                }

                if !viewModel.editMode.isEditing {
                    if isRadialMenuEnabled {
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
                            if tutorialStep == .openTaskList || tutorialStep == .explainLiveActivityFromPlus{
                                Circle()
                                    .stroke(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme), lineWidth: 3)
                                    .scaleEffect(tutorialPulse ? 1.35 : 1.05)
                                    .opacity(tutorialPulse ? 0.2 : 0.9)
                                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: tutorialPulse)
                                    .onAppear { tutorialPulse = true }
                            }
                        }
                        .contentShape(Circle())
                        .onTapGesture {
                            isTaskSheetPresented = true
                            if tutorialStep == .openTaskList {
                                tutorialStep = .placeTaskAfterNow
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isRadialMenuVisible {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                            isRadialMenuVisible = true
                                            radialSelection = nil
                                        }
                                    }
                                    let selection = radialAction(at: value.location, in: CGSize(width: 52, height: 52))
                                    radialSelection = selection
                                    if selection != nil, selection != lastHapticSelection {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.prepare()
                                        generator.impactOccurred()
                                        lastHapticSelection = selection
                                    }
                                }
                                .onEnded { _ in
                                    if isRadialMenuVisible, let selection = radialSelection {
                                        trigger(action: selection)
                                    }
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        isRadialMenuVisible = false
                                        radialSelection = nil
                                        lastHapticSelection = nil
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
                            if tutorialStep == .openTaskList || tutorialStep == .explainLiveActivityFromPlus{
                                Circle()
                                    .stroke(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme), lineWidth: 3)
                                    .scaleEffect(tutorialPulse ? 1.35 : 1.05)
                                    .opacity(tutorialPulse ? 0.2 : 0.9)
                                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: tutorialPulse)
                                    .onAppear { tutorialPulse = true }
                            }
                        }
                        .contentShape(Circle())
                        .onTapGesture {
                            isTaskSheetPresented = true
                            if tutorialStep == .openTaskList {
                                tutorialStep = .placeTaskAfterNow
                            }
                        }
                    }
                }
            }
            .padding(.trailing, 30)
            .padding(.bottom, 20)
        )
    }

    private func startFirstRunTutorialIfNeeded() {
        guard !isRunningInPreview else {
            tutorialStep = nil
            return
        }
        guard !isFirstRunTutorialCompleted else { return }
        ensureTutorialTaskExists()
        tutorialStep = .openTaskList
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

    private func refreshLiveActivityManually() async {
        guard !isLiveActivityRefreshing else { return }
        let startedAt = Date()
        await MainActor.run { isLiveActivityRefreshing = true }
        await viewModel.startOrUpdateLiveActivity()
        let remainingDisplayTime = 1.0 - Date().timeIntervalSince(startedAt)
        if remainingDisplayTime > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remainingDisplayTime * 1_000_000_000))
        }
        await MainActor.run { isLiveActivityRefreshing = false }
    }

    @ViewBuilder
    private func tutorialOverlay(step: TutorialStep) -> some View {
        let primary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let background = AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme)

        VStack(alignment: .leading, spacing: 8) {
            Text("はじめてガイド")
                .font(.caption.weight(.bold))
                .foregroundStyle(secondary)
            Text(step.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(step.primaryButtonTitle) {
                    advanceTutorialStep(from: step)
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                )
                .foregroundStyle(Color.white)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(secondary.opacity(0.22), lineWidth: 1)
        )
    }

    private func advanceTutorialStep(from step: TutorialStep) {
        switch step {
        case .openTaskList:
            tutorialStep = .placeTaskAfterNow
        case .placeTaskAfterNow:
            tutorialStep = .confirmCountdown
        case .confirmCountdown:
            tutorialStep = .explainLongPress
        case .explainLongPress:
            tutorialStep = .explainLiveActivityFromPlus
        case .explainLiveActivityFromPlus:
            tutorialStep = .explainSettingsAndSubscription
        case .explainSettingsAndSubscription:
            tutorialStep = nil
            isFirstRunTutorialCompleted = true
        }
    }
}

private enum TutorialStep {
    case openTaskList
    case placeTaskAfterNow
    case confirmCountdown
    case explainLongPress
    case explainLiveActivityFromPlus
    case explainSettingsAndSubscription

    var message: String {
        switch self {
        case .openTaskList:
            return "まずは右下の＋ボタンをタップして、タスクリストを開きましょう。"
        case .placeTaskAfterNow:
            return "「はじめてのタスク」をドラッグして、現在時刻より後のタイムラインへ置いてみましょう。"
        case .confirmCountdown:
            return "残り時間が表示されることを確認できました。次へ進みましょう。"
        case .explainLongPress:
            return "タイムライン上を長押しすると、その位置に新しいアイテムをすぐ置けます。"
        case .explainLiveActivityFromPlus:
            return "プラスボタンを押しながら上にスライドすると、ロック画面にカウントダウンが表示されるようになります。"
        case .explainSettingsAndSubscription:
            return "最後に日付の左側にある設定アイコンを確認しましょう。ここからテーマ変更やサブスク特典を確認でき、加入いただけると複数の予定を見やすく表示できます。"
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .explainSettingsAndSubscription:
            return "チュートリアル完了"
        default:
            return "次へ"
        }
    }
}

/// UIKit の UIDropInteraction でドロップを受け取る（SwiftUI の onDrop が効かない場合のフォールバック）
private struct ItemDropTarget: UIViewRepresentable {
    let onDrop: (UUID) -> Void
    var onDragEntered: (() -> Void)? = nil
    var onDragExited: (() -> Void)? = nil

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.addInteraction(UIDropInteraction(delegate: context.coordinator))
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onDrop = onDrop
        context.coordinator.onDragEntered = onDragEntered
        context.coordinator.onDragExited = onDragExited
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrop: onDrop, onDragEntered: onDragEntered, onDragExited: onDragExited)
    }

    class Coordinator: NSObject, UIDropInteractionDelegate {
        var onDrop: (UUID) -> Void
        var onDragEntered: (() -> Void)?
        var onDragExited: (() -> Void)?

        init(onDrop: @escaping (UUID) -> Void, onDragEntered: (() -> Void)?, onDragExited: (() -> Void)?) {
            self.onDrop = onDrop
            self.onDragEntered = onDragEntered
            self.onDragExited = onDragExited
        }

        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            session.canLoadObjects(ofClass: NSString.self) || session.hasItemsConforming(toTypeIdentifiers: [UTType.text.identifier])
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
            DispatchQueue.main.async { [weak self] in
                self?.onDragEntered?()
            }
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
            DispatchQueue.main.async { [weak self] in
                self?.onDragExited?()
            }
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            UIDropProposal(operation: .move)
        }

        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            guard let item = session.items.first else { return }
            let provider = item.itemProvider

            func complete(with id: UUID?) {
                guard let id else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.onDrop(id)
                }
            }

            if provider.canLoadObject(ofClass: NSString.self) {
                provider.loadObject(ofClass: NSString.self) { object, _ in
                    let id = (object as? String).flatMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    complete(with: id)
                }
                return
            }
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                let id: UUID? = {
                    if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    if let text = item as? String { return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    if let text = item as? NSString { return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines) as String) }
                    return nil
                }()
                complete(with: id)
            }
        }
    }
}

private struct HeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum RadialAction: CaseIterable {
    case settings
    case refreshLiveActivity

    var icon: String {
        switch self {
        case .settings: return "gearshape.fill"
        case .refreshLiveActivity: return "arrow.clockwise"
        }
    }

    var offset: CGSize {
        switch self {
        case .settings: return CGSize(width: -92, height: -56)
        case .refreshLiveActivity: return CGSize(width: 0, height: -110)
        }
    }
}

private extension TimelineScreen {
    var radialMenu: some View {
        let primary = AppColors.primary(palette: themeManager.theme, environmentScheme: colorScheme)
        let onAccent = AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme)
        return ZStack {
            ForEach(RadialAction.allCases, id: \.self) { action in
                Circle()
                    .fill(radialSelection == action ? primary : primary.opacity(0.6))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: action.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(onAccent)
                    )
                    .onTapGesture {
                        trigger(action: action)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            isRadialMenuVisible = false
                            radialSelection = nil
                        }
                    }
                    .offset(action.offset)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    func radialAction(at location: CGPoint, in size: CGSize) -> RadialAction? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let threshold: CGFloat = 22
        for action in RadialAction.allCases {
            let target = CGPoint(x: center.x + action.offset.width, y: center.y + action.offset.height)
            let dx = location.x - target.x
            let dy = location.y - target.y
            if sqrt(dx * dx + dy * dy) <= threshold {
                return action
            }
        }
        return nil
    }

    func trigger(action: RadialAction) {
        switch action {
        case .settings:
            isSettingsPresented = true
        case .refreshLiveActivity:
            Task { await refreshLiveActivityManually() }
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

