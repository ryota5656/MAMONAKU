import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ScheduleItemView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let item: TimelineItem
    let isEditing: Bool
    let showTimeRange: Bool
    let onEnterEdit: () -> Void
    let onResizePreview: (CGFloat) -> Void
    let onResizeEnd: (CGFloat) -> Void
    var onDragStart: ((UUID) -> Void)? = nil
    var onComplete: (() -> Void)? = nil
    var onUncomplete: (() -> Void)? = nil
    private let cornerRadius: CGFloat = 12
    private let leftBarWidth: CGFloat = 16
    @State private var isBubbleVisible = false
    @State private var isBubbleWiggling = false

    private var startTimeText: String {
        guard let start = item.startMinutes else { return "" }
        let h = start / 60
        let m = start % 60
        return String(format: "%02d:%02d", h, m)
    }

    private var endTimeText: String {
        guard let start = item.startMinutes else { return "" }
        let endMinutes = (start + item.durationMinutes) % (24 * 60)
        let h = endMinutes / 60
        let m = endMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    private var timeRangeText: String {
        guard !startTimeText.isEmpty else { return "" }
        return "\(startTimeText) - \(endTimeText)"
    }

    private var surfaceColor: Color {
        AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme)
    }

    private var primaryTextColor: Color {
        AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
    }

    private var secondaryTextColor: Color {
        AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
    }

    private var leftRailColor: Color {
        AppColors.itemCardColors(palette: themeManager.theme, environmentScheme: colorScheme).first ?? .white
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 12) {
                    Capsule(style: .continuous)
                        .fill(leftRailColor)
                        .frame(width: leftBarWidth)
                        .frame(maxHeight: .infinity)
                        .overlay(alignment: .center) {
                            if geo.size.height >= 56 {
//                                Image(systemName: "heart.fill")
//                                    .font(.system(size: 12, weight: .semibold))
//                                    .foregroundStyle(surfaceColor.opacity(0.95))
                            }
                        }

                    VStack(alignment: .leading) {
                        if showTimeRange, !timeRangeText.isEmpty {
                            Text(timeRangeText)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(secondaryTextColor)
                        }

                        Text(item.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(2)
//                            .padding(.top, 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
//                .padding(.horizontal, 12)
//                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.clear)
//                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
//        .contentShape(Rectangle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6, maximumDistance: 10)
                .onEnded { _ in
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                    onEnterEdit()
                }
        )
        .contentShape(Rectangle())
        .modifier(ConditionalOnDragModifier(condition: true, itemID: item.id, onDragStart: onDragStart))
        .overlay(alignment: .bottom) {
            if isEditing {
                VStack(spacing: 0) {
                    resizeHandle
                        .contentShape(Rectangle())
                        .highPriorityGesture(resizeGesture)
                    resizeHandleDot
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if isBubbleVisible && !isEditing {
                bubbleView
                    .transition(.scale.combined(with: .opacity))
                    .offset(x: 16, y: -12)
                    .rotationEffect(.degrees(isBubbleWiggling ? 2.0 : -2.0), anchor: .bottomLeading)
                    .offset(x: isBubbleWiggling ? 3 : -3)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isBubbleWiggling)
                    .onAppear { isBubbleWiggling = true }
                    .onDisappear { isBubbleWiggling = false }
                    .zIndex(1)
            }
        }
        .overlay {
            if isEditing {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.itemCardColors(palette: themeManager.theme, environmentScheme: colorScheme).first ?? .white, style: StrokeStyle(lineWidth: 1.5, dash: [4, 9]))
            } else {
                //                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                //                    .stroke(AppColors.cardStroke(palette: themeManager.theme, environmentScheme: colorScheme), style: StrokeStyle(lineWidth: 1.5, dash: [100, 0]))
            }
        }
//        .overlay(
//            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                .stroke(
//                    isEditing ? AppColors.accent.opacity(0.9) : AppColors.accent.opacity(0.2),
//                    lineWidth: isEditing ? 2 : 1
//                )
//        )
//        .background(
//            RoundedRectangle(cornerRadius: 10, style: .continuous)
//                .fill(AppColors.accent.opacity(0.01))
//        )
        .overlay(alignment: .topTrailing) {
            if item.isCompleted, let onUncomplete {
                Button(action: onUncomplete) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(primaryTextColor.opacity(0.9))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .padding(10)
            } else if !item.isCompleted, let onComplete {
                Button(action: onComplete) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(primaryTextColor.opacity(0.9))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onResizePreview(value.translation.height)
            }
            .onEnded { value in
                onResizeEnd(value.translation.height)
            }
    }

    // 時間を可変できるハンドル（タップ領域）
    private var resizeHandle: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .frame(width: .infinity, height: 15)
            .opacity(0.01)
    }

    // 下に伸ばせることを示す丸
    private var resizeHandleDot: some View {
        Circle()
            .fill(leftRailColor)
            .frame(width: 8, height: 8)
            .offset(y: 3)
    }

    private var bubbleView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.id.uuidString)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                )
            Triangle()
                .fill(Color(.systemBackground))
                .frame(width: 10, height: 6)
                .padding(.leading, 14)
                .offset(y: -1)
        }
        .shadow(color: Color.primary.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

private struct ConditionalOnDragModifier: ViewModifier {
    let condition: Bool
    let itemID: UUID
    var onDragStart: ((UUID) -> Void)? = nil

    func body(content: Content) -> some View {
        if condition {
            content.onDrag {
                onDragStart?(itemID)
                return NSItemProvider(object: itemID.uuidString as NSString)
            }
        } else {
            content
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview("scheduleItem"){
    ScheduleItemView(
        item: TimelineItem(title: "TEST", durationMinutes: 60, startMinutes: 90, dropDate: Date()),
        isEditing: false,
        showTimeRange: true,
        onEnterEdit: {},
        onResizePreview: { _ in },
        onResizeEnd: { _ in }
    )
    .frame(height: 100)
    .padding(20)
    .environmentObject(ThemeManager())
}

#Preview("scheduleItemEdit"){
    ScheduleItemView(
        item: TimelineItem(title: "TEST", durationMinutes: 60, startMinutes: 90, dropDate: Date()),
        isEditing: true,
        showTimeRange: true,
        onEnterEdit: {},
        onResizePreview: { _ in },
        onResizeEnd: { _ in }
    )
    .frame(height: 100)
    .padding(20)
    .environmentObject(ThemeManager())
}
