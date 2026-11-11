import SwiftUI

/// 画面下部に浮かぶ Stock（未配置タスク置き場）のカード。
///
/// - ヘッダーをタップ: タスクを作成
/// - チップをタップ: タスクを編集 / ドラッグ: タイムラインへ配置、または Stock 内で並べ替え
/// - タイムライン上の予定をここへドロップ: Stock に戻す
///
/// タブバーの Liquid Glass に合わせた半透明のガラス表現にしている。
struct TimelineStockCard: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let stockItems: [TimelineItem]
    /// タイムライン上の予定をドラッグ中か（その間だけドロップを受け付ける）
    let isDraggingPlacedItem: Bool
    /// チュートリアル中の強調表示
    var isTutorialHighlighted = false
    let onTapAdd: () -> Void
    let onTapRoutines: () -> Void
    let onTapItem: (UUID) -> Void
    let onDragBegan: (UUID) -> Void
    let onDragEnded: () -> Void
    let onReorder: (_ fromIndex: Int, _ toOffset: Int) -> Void
    /// タイムライン上の予定がドロップされた
    let onDropPlacedItem: (UUID) -> Void

    /// ドラッグ中の予定がカードの上にあるか
    @State private var isDropTargeted = false
    @State private var tutorialHighlightPulse = false

    private let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        VStack(spacing: 10) {
            header
            chipList
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .modifier(
            StockCardGlassBackground(
                shape: cardShape,
                isDropTargeted: isDropTargeted,
                accent: theme.accent
            )
        )
        .clipShape(cardShape)
        .overlay {
            cardShape
                .strokeBorder(theme.accent.opacity(isDropTargeted ? 0.55 : 0), lineWidth: 1.5)
                .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
                .allowsHitTesting(false)
        }
        .overlay {
            if isTutorialHighlighted {
                tutorialHighlight
            }
        }
        .overlay {
            dropTarget
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - ヘッダー（タップで作成）

    private var header: some View {
        HStack(spacing: 4) {
            Button(action: onTapAdd) {
                HStack(spacing: 8) {
                    Text(isDropTargeted ? "タスクリストへ戻す" : "Stock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isDropTargeted ? theme.accent : theme.textPrimary)
                    Spacer()
                    if isDropTargeted {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    } else {
                        if !stockItems.isEmpty {
                            Text("\(stockItems.count)件")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                        }
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isDropTargeted {
                Button(action: onTapRoutines) {
                    Image(systemName: "repeat")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("ルーティン")
            }
        }
        .allowsHitTesting(!isDraggingPlacedItem)
    }

    // MARK: - タスクのチップ

    private var chipList: some View {
        // 空↔1件で View を差し替えると UICollectionView が再生成され、
        // 初回セルがレイアウトされないことがあるため常にマウントする
        ZStack(alignment: .leading) {
            TimelineStockChipList(
                items: stockItems,
                theme: theme,
                colorScheme: colorScheme,
                onTap: onTapItem,
                onDragBegan: onDragBegan,
                onDragEnded: onDragEnded,
                onReorder: onReorder
            )
            .opacity(stockItems.isEmpty ? 0 : 1)
            .allowsHitTesting(!stockItems.isEmpty && !isDraggingPlacedItem)

            if stockItems.isEmpty {
                Text(isDropTargeted ? "ここにドロップ" : "タスクがありません")
                    .font(.system(size: 12))
                    .foregroundStyle(isDropTargeted ? theme.accent : theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: TimelineStockChipList.chipHeight)
        .clipped()
    }

    // MARK: - チュートリアルの強調

    private var tutorialHighlight: some View {
        cardShape
            .stroke(theme.strongAccent, lineWidth: 3)
            .scaleEffect(tutorialHighlightPulse ? 1.03 : 1.0)
            .opacity(tutorialHighlightPulse ? 0.35 : 0.95)
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: tutorialHighlightPulse
            )
            .allowsHitTesting(false)
            .onAppear { tutorialHighlightPulse = true }
    }

    // MARK: - Stock へ戻すドロップ

    private var dropTarget: some View {
        ItemDropTarget(
            onDrop: { id in
                isDropTargeted = false
                onDropPlacedItem(id)
            },
            onDragEntered: {
                guard isDraggingPlacedItem else { return }
                Haptics.impact(.light)
                isDropTargeted = true
            },
            onDragExited: {
                isDropTargeted = false
            },
            absorbsHits: isDraggingPlacedItem
        )
    }
}

/// タブバーと同系の Liquid Glass。iOS 26 未満は Material で近似する。
private struct StockCardGlassBackground: ViewModifier {
    let shape: RoundedRectangle
    let isDropTargeted: Bool
    let accent: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                isDropTargeted ? .regular.tint(accent.opacity(0.35)) : .regular,
                in: shape
            )
        } else {
            content
                .background {
                    shape
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
                }
                .background {
                    if isDropTargeted {
                        shape.fill(accent.opacity(0.12))
                    }
                }
        }
    }
}

#Preview("TimelineStockCard") {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.35), Color.purple.opacity(0.25), Color.orange.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        TimelineStockCard(
            stockItems: [
                TimelineItem(title: "買い物", durationMinutes: 30),
                TimelineItem(title: "読書", durationMinutes: 45)
            ],
            isDraggingPlacedItem: false,
            onTapAdd: {},
            onTapRoutines: {},
            onTapItem: { _ in },
            onDragBegan: { _ in },
            onDragEnded: {},
            onReorder: { _, _ in },
            onDropPlacedItem: { _ in }
        )
        .padding(.horizontal, 16)
    }
}
