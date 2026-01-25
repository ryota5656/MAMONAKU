import SwiftUI

struct ScheduleItemView: View {
    let item: ScheduleItem
    let isEditing: Bool
    let onEnterEdit: () -> Void
    let onMovePreview: (CGFloat) -> Void
    let onMoveEnd: (CGFloat) -> Void
    let onResizePreview: (CGFloat) -> Void
    let onResizeEnd: (CGFloat) -> Void
    let onDelete: () -> Void
    private let cornerRadius: CGFloat = 5

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.black)
                    .frame(width: 8)

            VStack(alignment: .leading, spacing: 4) {
                if item.durationMinutes != 15 {
                    Text(timeRangeText())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
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

    private var resizeHandle: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .frame(width: 20, height: 5)
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

    private func timeRangeText() -> String {
        let start = minutesToTime(item.startMinutes)
        let end = minutesToTime(item.startMinutes + item.durationMinutes)
        return "\(start) - \(end)"
    }

    private func minutesToTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    private var accentColor: Color {
        Color.black
    }
}
