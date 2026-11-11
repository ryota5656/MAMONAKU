import SwiftUI

/// タイムライン上の予定 1 件。
///
/// - 長押し: 編集モードへ入る
/// - ドラッグ: 別の時刻・日付へ移動、または Stock へ戻す
/// - 編集モード中: タイトルをタップして変更、下端のハンドルで所要時間を変更
struct TimelineItemCard: View {
    @Environment(\.appTheme) private var theme

    let item: TimelineItem
    let isEditing: Bool
    /// 高さに余裕があるときだけ時間帯を表示する
    let showsTimeRange: Bool
    let onLongPress: () -> Void
    let onRename: (String) -> Void
    /// リサイズハンドルをドラッグ中（開始からの縦移動量）
    let onResizeChanged: (CGFloat) -> Void
    let onResizeEnded: (CGFloat) -> Void
    let onDragStart: () -> Void

    @State private var draftTitle = ""
    @State private var isTitleEditing = false
    @FocusState private var isTitleFocused: Bool

    private let railWidth: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 12) {
                Capsule(style: .continuous)
                    .fill(theme.itemCardColor)
                    .frame(width: railWidth)
                    .frame(maxHeight: .infinity)

                labels
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 高さが足りない短い予定でも枠の大きさは変えず、文字をはみ出させる。
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6, maximumDistance: 10)
                .onEnded { _ in
                    Haptics.impact(.medium)
                    onLongPress()
                }
        )
        .contentShape(Rectangle())
        .onDrag {
            onDragStart()
            return ItemDragPayload.itemProvider(for: item.id)
        }
        .overlay(alignment: .bottom) {
            if isEditing {
                resizeHandle
            }
        }
        .overlay {
            if isEditing {
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .stroke(theme.itemCardColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 9]))
            }
        }
        .onAppear {
            draftTitle = item.title
        }
        .onChange(of: item.id) { _, _ in
            draftTitle = item.title
        }
        .onChange(of: item.title) { _, title in
            if !isTitleFocused {
                draftTitle = title
            }
        }
        .onChange(of: isEditing) { _, isEditing in
            if isEditing {
                draftTitle = item.title
            } else {
                endTitleEditing()
                isTitleFocused = false
            }
        }
        .onChange(of: isTitleFocused) { _, isFocused in
            if !isFocused {
                endTitleEditing()
            }
        }
    }

    // MARK: - 時間帯とタイトル

    private var labels: some View {
        VStack(alignment: .leading) {
            if showsTimeRange, let startMinutes = item.startMinutes {
                Text(DayTime.rangeText(startMinutes: startMinutes, durationMinutes: item.durationMinutes))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }

            if isEditing && isTitleEditing {
                TextField("タイトル", text: $draftTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .submitLabel(.done)
                    .focused($isTitleFocused)
                    .onSubmit {
                        endTitleEditing()
                        isTitleFocused = false
                    }
            } else {
                Text(item.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isEditing else { return }
                        beginTitleEditing()
                    }
            }
        }
    }

    private func beginTitleEditing() {
        draftTitle = item.title
        isTitleEditing = true
        // TextField が表示されてからフォーカスを当てる
        DispatchQueue.main.async {
            isTitleFocused = true
        }
    }

    /// タイトル入力を終え、変更があれば通知する。空のタイトルは元に戻す。
    private func endTitleEditing() {
        guard isTitleEditing else { return }
        isTitleEditing = false

        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            draftTitle = item.title
            return
        }
        guard title != item.title else { return }
        draftTitle = title
        onRename(title)
    }

    // MARK: - リサイズハンドル

    private var resizeHandle: some View {
        VStack(spacing: 0) {
            // タップ領域（見えない）
            Rectangle()
                .frame(height: 15)
                .opacity(0.01)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { onResizeChanged($0.translation.height) }
                        .onEnded { onResizeEnded($0.translation.height) }
                )
            // 下に伸ばせることを示す丸
            Circle()
                .fill(theme.itemCardColor)
                .frame(width: 8, height: 8)
                .offset(y: 3)
        }
    }
}

#Preview("通常") {
    TimelineItemCard(
        item: TimelineItem(title: "TEST", durationMinutes: 60, startMinutes: 90, dropDate: Date()),
        isEditing: false,
        showsTimeRange: true,
        onLongPress: {},
        onRename: { _ in },
        onResizeChanged: { _ in },
        onResizeEnded: { _ in },
        onDragStart: {}
    )
    .frame(height: 100)
    .padding(20)
}

#Preview("編集モード") {
    TimelineItemCard(
        item: TimelineItem(title: "TEST", durationMinutes: 60, startMinutes: 90, dropDate: Date()),
        isEditing: true,
        showsTimeRange: true,
        onLongPress: {},
        onRename: { _ in },
        onResizeChanged: { _ in },
        onResizeEnded: { _ in },
        onDragStart: {}
    )
    .frame(height: 100)
    .padding(20)
}
