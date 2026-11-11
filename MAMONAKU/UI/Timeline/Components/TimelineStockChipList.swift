import SwiftUI
import UIKit

/// Stock のタスクを横に並べるリスト。
///
/// 長押しドラッグでの並べ替えと、タイムラインへのドラッグ＆ドロップを両立させるため UICollectionView を使う。
/// 表示するのは先頭 `maximumVisibleItems` 件まで。
struct TimelineStockChipList: UIViewRepresentable {
    static let chipHeight: CGFloat = 40
    private static let maximumVisibleItems = 20

    let items: [TimelineItem]
    /// セル内の SwiftUI View へ渡す配色（セルは別のホスティング階層になり、Environment を引き継がないため）
    let theme: AppTheme
    let colorScheme: ColorScheme
    let onTap: (UUID) -> Void
    let onDragBegan: (UUID) -> Void
    let onDragEnded: () -> Void
    /// 並べ替えた。第 2 引数は、動かす前の並びで数えた挿入先。
    let onReorder: (_ fromIndex: Int, _ toOffset: Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        // automaticSize + Hosting は1件時に幅0になることがあるため、明示サイズを使う
        layout.estimatedItemSize = .zero
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = .zero

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.clipsToBounds = true
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dragInteractionEnabled = true
        collectionView.reorderingCadence = .immediate
        collectionView.delegate = context.coordinator
        collectionView.dragDelegate = context.coordinator
        collectionView.dropDelegate = context.coordinator
        context.coordinator.configure(collectionView: collectionView)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.reload(items: Array(items.prefix(Self.maximumVisibleItems)), in: collectionView)
    }

    /// セルと寸法計測の両方で使う、チップ 1 件分の View。
    fileprivate func chip(for item: TimelineItem) -> some View {
        TimelineStockChipItem(item: item)
            .environment(\.appTheme, theme)
            .environment(\.colorScheme, colorScheme)
    }

    final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
        var parent: TimelineStockChipList
        private var items: [TimelineItem] = []
        private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>?
        private var sizeCache: [UUID: CGSize] = [:]

        init(parent: TimelineStockChipList) {
            self.parent = parent
        }

        func configure(collectionView: UICollectionView) {
            collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "chip")

            dataSource = UICollectionViewDiffableDataSource<Int, UUID>(collectionView: collectionView) { [weak self] collectionView, indexPath, id in
                guard let self,
                      let item = self.items.first(where: { $0.id == id })
                else { return nil }

                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "chip", for: indexPath)
                cell.contentConfiguration = UIHostingConfiguration {
                    self.parent.chip(for: item)
                }
                .margins(.all, 0)
                cell.backgroundConfiguration = .clear()
                cell.clipsToBounds = true
                cell.contentView.clipsToBounds = true
                return cell
            }
        }

        func reload(items newItems: [TimelineItem], in collectionView: UICollectionView) {
            let previousIDs = items.map(\.id)
            let nextIDs = newItems.map(\.id)
            items = newItems
            sizeCache = Dictionary(uniqueKeysWithValues: newItems.map { ($0.id, measure($0)) })

            if previousIDs == nextIDs {
                // 並びが同じなら、中身（タイトル・配色など）だけ描き直す
                guard let dataSource else { return }
                var snapshot = dataSource.snapshot()
                if !nextIDs.isEmpty {
                    snapshot.reconfigureItems(nextIDs)
                }
                dataSource.apply(snapshot, animatingDifferences: false)
                collectionView.collectionViewLayout.invalidateLayout()
                return
            }

            var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
            snapshot.appendSections([0])
            snapshot.appendItems(nextIDs, toSection: 0)

            // 件数変化（特に 0→1）はアニメなしで確実に載せる
            dataSource?.apply(snapshot, animatingDifferences: false) {
                collectionView.collectionViewLayout.invalidateLayout()
                collectionView.layoutIfNeeded()
            }

            DispatchQueue.main.async {
                collectionView.collectionViewLayout.invalidateLayout()
                collectionView.layoutIfNeeded()
            }
        }

        private func measure(_ item: TimelineItem) -> CGSize {
            let controller = UIHostingController(rootView: parent.chip(for: item))
            controller.view.backgroundColor = .clear
            let size = controller.sizeThatFits(in: CGSize(
                width: UIView.layoutFittingExpandedSize.width,
                height: TimelineStockChipList.chipHeight
            ))
            return CGSize(
                width: max(ceil(size.width), 44),
                height: TimelineStockChipList.chipHeight
            )
        }

        // MARK: UICollectionViewDelegateFlowLayout

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            guard items.indices.contains(indexPath.item) else {
                return CGSize(width: 80, height: TimelineStockChipList.chipHeight)
            }
            let item = items[indexPath.item]
            if let cached = sizeCache[item.id] {
                return cached
            }
            let size = measure(item)
            sizeCache[item.id] = size
            return size
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard items.indices.contains(indexPath.item) else { return }
            parent.onTap(items[indexPath.item].id)
        }

        // MARK: UICollectionViewDragDelegate

        func collectionView(
            _ collectionView: UICollectionView,
            itemsForBeginning session: UIDragSession,
            at indexPath: IndexPath
        ) -> [UIDragItem] {
            guard items.indices.contains(indexPath.item) else { return [] }
            let item = items[indexPath.item]
            parent.onDragBegan(item.id)
            let dragItem = UIDragItem(itemProvider: ItemDragPayload.itemProvider(for: item.id))
            dragItem.localObject = item.id
            return [dragItem]
        }

        func collectionView(
            _ collectionView: UICollectionView,
            dragSessionDidEnd session: UIDragSession
        ) {
            parent.onDragEnded()
        }

        // MARK: UICollectionViewDropDelegate（Stock 内の並べ替え）

        func collectionView(
            _ collectionView: UICollectionView,
            dropSessionDidUpdate session: UIDropSession,
            withDestinationIndexPath destinationIndexPath: IndexPath?
        ) -> UICollectionViewDropProposal {
            guard session.localDragSession != nil else {
                return UICollectionViewDropProposal(operation: .cancel)
            }
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }

        func collectionView(
            _ collectionView: UICollectionView,
            performDropWith coordinator: UICollectionViewDropCoordinator
        ) {
            guard let item = coordinator.items.first,
                  let sourceIndexPath = item.sourceIndexPath
            else { return }

            let destinationIndexPath = coordinator.destinationIndexPath
                ?? IndexPath(item: max(items.count - 1, 0), section: 0)

            // 後ろへ動かす場合、挿入先は「動かす前の並び」で 1 つ後ろになる
            var toOffset = destinationIndexPath.item
            if sourceIndexPath.item < toOffset {
                toOffset += 1
            }

            parent.onReorder(sourceIndexPath.item, toOffset)
            coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
            parent.onDragEnded()
        }
    }
}
