import SwiftUI

struct ScheduleItemView: View {
    let item: TimelineItem
    let isEditing: Bool
    let onEnterEdit: () -> Void
    let onMovePreview: (CGFloat) -> Void
    let onMoveEnd: (CGFloat) -> Void
    let onResizePreview: (CGFloat) -> Void
    let onResizeEnd: (CGFloat) -> Void
    let onDelete: () -> Void
    private let cornerRadius: CGFloat = 5
    @State private var isBubbleVisible = false
    @State private var isBubbleWiggling = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.black)
                    .frame(width: 8)

            VStack(alignment: .leading, spacing: 4) {
                if item.durationMinutes != 15, item.startMinutes != nil {
                    Text(TimelineViewModel.timeRangeText(
                        startMinutes: item.startMinutes,
                        durationMinutes: item.durationMinutes
                    ))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal,12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            if isEditing {
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                        .foregroundColor(.black)
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    guard !isEditing else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        isBubbleVisible.toggle()
                    }
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6, maximumDistance: 10)
                .onEnded { _ in
                    onEnterEdit()
                }
        )
        .simultaneousGesture(moveGesture, including: isEditing ? .all : .subviews)
        .overlay(alignment: .bottomTrailing) {
            if !isEditing {
                moveHandle
                    .gesture(alwaysMoveGesture)
            }
        }
        .overlay(alignment: .bottom) {
            if isEditing {
                resizeHandle
                    .contentShape(Rectangle())
                    .highPriorityGesture(resizeGesture)
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
    }

    private var alwaysMoveGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                onMovePreview(value.translation.height)
            }
            .onEnded { value in
                onMoveEnd(value.translation.height)
            }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard isEditing else { return }
                onMovePreview(value.translation.height)
            }
            .onEnded { value in
                guard isEditing else { return }
                onMoveEnd(value.translation.height)
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

    // 時間を可変できるハンドル
    private var resizeHandle: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .frame(width: 30, height: 7)
            .padding(.bottom, 6)
            .padding(.trailing, 10)
    }

    private var moveHandle: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.black.opacity(0.01))
            .overlay(
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.5))
            )
            .frame(width: 28, height: 18)
            .padding(.top, 6)
            .padding(.leading, 8)
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
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                )
            Triangle()
                .fill(Color(.systemBackground))
                .frame(width: 10, height: 6)
                .padding(.leading, 14)
                .offset(y: -1)
        }
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
    }

    private var accentColor: Color {
        Color.black
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
        onEnterEdit: {},
        onMovePreview: { _ in },
        onMoveEnd: { _ in },
        onResizePreview: { _ in },
        onResizeEnd: { _ in },
        onDelete: {}
    )
    .frame(height: 100)
    .padding(20)
}
