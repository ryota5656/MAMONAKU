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

                WhiteSheetView(
                    viewModel: viewModel,
                    sheetHeight: $sheetHeight
                )
                .offset(y: isHeaderExpanded ? (headerHeight + 12) : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isHeaderExpanded)

                }
                .sheet(isPresented: $isTaskSheetPresented) {
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
                        onAddDebugTask: {
                            viewModel.addTestTask(startDate: Date().addingTimeInterval(60), durationMinutes: 15)
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
                .onChange(of: viewModel.dropPreview) { _, preview in
                    guard isTaskSheetPresented, isDraggingTask, preview != nil else { return }
                    isDraggingTask = false
                    isTaskSheetPresented = false
                }
                .overlay(alignment: .bottomLeading) {
                    Group {
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
                                        Circle()
                                            .foregroundStyle(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                                        Image(systemName: "trash.circle.fill")
                                            .font(.system(size: 35))
                                            .foregroundStyle(.white)
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
                                    .foregroundStyle(Color.primary.opacity(0.8))
                                    .shadow(color: Color.primary.opacity(0.2), radius: 6, x: 0, y: 3)
                            }
                            .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.leading, 30)
                    .padding(.bottom, 20)
                }
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        let accent = AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)
                        let onAccent = AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme)
                        if isRadialMenuVisible {
                            radialMenu
                        }

                        // 編集モード中: ストックに戻す（ドロップでストックに戻す）。位置・サイズは通常時のプラスボタンと同じ。
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
                                            .foregroundStyle(accent.opacity(0.9))
                                        Image(systemName: "tray.and.arrow.down")
                                            .font(.system(size: 20, weight: .bold))
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
                            ZStack {
                                Circle()
                                    .foregroundStyle(accent.opacity(0.9))
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(onAccent)
                                    .shadow(color: Color.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                            }
                            .frame(width: 35, height: 35)
                            .contentShape(Circle())
                            .onTapGesture {
                                isTaskSheetPresented = true
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
                        }
                    }
                    .padding(.trailing, 30)
                    .padding(.bottom, 20)
                }
            .onPreferenceChange(HeaderHeightKey.self) { value in
                headerHeight = value
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
//            .background(
//                Color.clear
//                    .contentShape(Rectangle())
//                    .onTapGesture {
//                        if viewModel.editMode.isEditing {
//                            viewModel.editMode = .inactive
//                        }
//                    }
//            )
            .onAppear {
                viewModel.updateLiveActivity()
            }
            .onChange(of: viewModel.items) { _, _ in
                viewModel.updateLiveActivity()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    viewModel.updateLiveActivity()
                case .inactive, .background:
                    viewModel.updateLiveActivity()
                @unknown default:
                    break
                }
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
    case actionA
    case actionB
    case actionC

    var icon: String {
        switch self {
        case .actionA: return "gearshape"
        case .actionB: return "clock"
        case .actionC: return "flag"
        }
    }

    var offset: CGSize {
        switch self {
        case .actionA: return CGSize(width: -110, height: 0)
        case .actionB: return CGSize(width: 0, height: -110)
        case .actionC: return CGSize(width: -80, height: -80)
        }
    }
}

private extension TimelineScreen {
    var radialMenu: some View {
        let accent = AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)
        let onAccent = AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme)
        return ZStack {
            ForEach(RadialAction.allCases, id: \.self) { action in
                Circle()
                    .fill(radialSelection == action ? accent : accent.opacity(0.85))
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
        // Placeholder: implement specific actions later.
        switch action {
        case .actionA:
            isSettingsPresented = true
        case .actionB, .actionC:
            break
        }
    }
}

#Preview{
    ContentView()
        .environmentObject(ThemeManager())
}
#Preview("scheduleItemPreview"){
    ScheduleItemPreviewView(
        item: TimelineItem(title: "Preview", durationMinutes: 60, startMinutes: 120),
        showTimeRange: true
    )
    .frame(height: 100)
    .padding(20)
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
