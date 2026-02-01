import SwiftUI

struct TimelineStockView: View {
    let items: [TimelineItem]
    @Binding var chipsExpanded: Bool
    @Binding var dragItemID: UUID?
    let onAdd: (String, Int) -> Void
    let onMove: (IndexSet, Int, Int) -> Void
    let onDelete: (UUID) -> Void

    @State private var newTitle = ""
    @State private var newDurationMinutes = 30
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        let visible = chipsExpanded ? items.filter { $0.dropDate == nil } : []
        let rowHeight: CGFloat = 40
        let maxRows = 3
        let displayRows = min(visible.count, maxRows)

        VStack(spacing: 8) {
            if !visible.isEmpty {
                listView(visible: visible, displayRows: displayRows, rowHeight: rowHeight)
            }

            headerView
        }
        .padding(8)
        .padding(.bottom, keyboardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: chipsExpanded)
        .animation(.easeInOut(duration: 0.2), value: keyboardHeight)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            keyboardHeight = keyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private var canAdd: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func keyboardHeight(from notification: Notification) -> CGFloat {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }
        return frame.height
    }

    @ViewBuilder
    private func listView(visible: [TimelineItem], displayRows: Int, rowHeight: CGFloat) -> some View {
        List {
            ForEach(visible) { item in
                DraggableChip(item: item, dragItemID: $dragItemID)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(item.id)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
            }
            .onDelete { offsets in
                offsets.map { visible[$0].id }.forEach(onDelete)
            }
            .onMove { from, to in
                onMove(from, to, visible.count)
            }
        }
        .environment(\.defaultMinListRowHeight, 0)
        .listStyle(.plain)
        .frame(height: rowHeight * CGFloat(displayRows))
    }

    private var headerView: some View {
        HStack {
            TextField("タイトル", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

            durationMenu

            Button {
                onAdd(newTitle, newDurationMinutes)
                newTitle = ""
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(canAdd ? Color.accentColor : Color.secondary)
            }
            .disabled(!canAdd)
            .padding(.trailing, 10)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    chipsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: chipsExpanded ? "chevron.down" : "chevron.up")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.trailing, 10)
        }
    }

    private var durationMenu: some View {
        Menu {
            Picker("", selection: $newDurationMinutes) {
                ForEach(Array(stride(from: 15, through: 240, by: 15)), id: \.self) { minutes in
                    Text("\(minutes) min")
                        .font(.system(size: 10))
                }
            }
            .tint(.black)
        } label: {
            Text("\(newDurationMinutes) min")
                .font(.system(size: 12, weight: .semibold))
                .tint(Color.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }
}

private struct DraggableChip: View {
    let item: TimelineItem
    @Binding var dragItemID: UUID?

    var body: some View {
        HStack {
            Text(item.title)
                .font(.system(size: 12, weight: .bold))
            Spacer()
            Text("\(item.durationMinutes)min")
                .font(.system(size: 12))
                .padding(10)
        }
        .onDrag {
            dragItemID = item.id
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .frame(height: 10)
//        Text(item.title)
//            .font(.system(size: 12, weight: .bold))
//            .padding(.horizontal, 12)
////            .padding(.vertical, 8)
//            .cornerRadius(8)
//            .onDrag {
//                dragItemID = item.id
//                return NSItemProvider(object: item.id.uuidString as NSString)
//            }
    }
}

#Preview("Stock") {
    @Previewable @State var chipsExpanded = true
    @Previewable @State var dragItemID: UUID? = nil

    let items: [TimelineItem] = [
        TimelineItem(id: UUID(), title: "Item A", durationMinutes: 30, dropDate: nil),
        TimelineItem(id: UUID(), title: "Item B", durationMinutes: 60, dropDate: nil),
        TimelineItem(id: UUID(), title: "Item C", durationMinutes: 90, dropDate: nil),
        TimelineItem(id: UUID(), title: "Item A", durationMinutes: 30, dropDate: nil),
        TimelineItem(id: UUID(), title: "Item B", durationMinutes: 60, dropDate: nil),
        TimelineItem(id: UUID(), title: "Item C", durationMinutes: 90, dropDate: nil),
    ]

    TimelineStockView(
        items: items,
        chipsExpanded: $chipsExpanded,
        dragItemID: $dragItemID,
        onAdd: { _, _ in },
        onMove: { from, to, visibleCount in
            // no-op in preview
        },
        onDelete: { _ in }
    )
}

