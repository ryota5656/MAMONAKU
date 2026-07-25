import SwiftUI
import UIKit

/// 横スクロール＋チップデザインを維持しつつ、List 相当の滑らかな並べ替えを行う Stock リスト
struct HorizontalStockChipList: UIViewRepresentable {
    let items: [TimelineItem]
    @Binding var isDraggingTask: Bool
    @Binding var dragItemID: UUID?
    let heightForDuration: (Int) -> CGFloat
    let themeManager: ThemeManager
    let colorScheme: ColorScheme
    let onTap: (TimelineItem) -> Void
    let onReorder: (IndexSet, Int) -> Void

    private let chipHeight: CGFloat = 40

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
        context.coordinator.reload(items: Array(items.prefix(20)), in: collectionView)
    }

    final class Coordinator: NSObject, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
        var parent: HorizontalStockChipList
        private var items: [TimelineItem] = []
        private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>?
        private var sizeCache: [UUID: CGSize] = [:]
        private weak var collectionView: UICollectionView?

        init(parent: HorizontalStockChipList) {
            self.parent = parent
        }

        func configure(collectionView: UICollectionView) {
            self.collectionView = collectionView
            collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "chip")

            dataSource = UICollectionViewDiffableDataSource<Int, UUID>(collectionView: collectionView) { [weak self] collectionView, indexPath, id in
                guard let self,
                      let item = self.items.first(where: { $0.id == id })
                else { return nil }

                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "chip", for: indexPath)
                cell.contentConfiguration = UIHostingConfiguration {
                    TaskStockPeekChipView(
                        item: item,
                        isDraggingTask: .constant(false),
                        dragItemID: .constant(nil),
                        heightForDuration: self.parent.heightForDuration,
                        interactionStyle: .displayOnly
                    )
                    .environmentObject(self.parent.themeManager)
                    .environment(\.colorScheme, self.parent.colorScheme)
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
            let view = TaskStockPeekChipView(
                item: item,
                isDraggingTask: .constant(false),
                dragItemID: .constant(nil),
                heightForDuration: parent.heightForDuration,
                interactionStyle: .displayOnly
            )
            .environmentObject(parent.themeManager)
            .environment(\.colorScheme, parent.colorScheme)

            let controller = UIHostingController(rootView: view)
            controller.view.backgroundColor = .clear
            let size = controller.sizeThatFits(in: CGSize(
                width: UIView.layoutFittingExpandedSize.width,
                height: parent.chipHeight
            ))
            return CGSize(
                width: max(ceil(size.width), 44),
                height: parent.chipHeight
            )
        }

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            guard items.indices.contains(indexPath.item) else {
                return CGSize(width: 80, height: parent.chipHeight)
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
            parent.onTap(items[indexPath.item])
        }

        func collectionView(
            _ collectionView: UICollectionView,
            itemsForBeginning session: UIDragSession,
            at indexPath: IndexPath
        ) -> [UIDragItem] {
            guard items.indices.contains(indexPath.item) else { return [] }
            let item = items[indexPath.item]
            parent.isDraggingTask = true
            parent.dragItemID = item.id
            let provider = NSItemProvider(object: item.id.uuidString as NSString)
            let dragItem = UIDragItem(itemProvider: provider)
            dragItem.localObject = item.id
            return [dragItem]
        }

        func collectionView(
            _ collectionView: UICollectionView,
            dragSessionDidEnd session: UIDragSession
        ) {
            parent.isDraggingTask = false
            parent.dragItemID = nil
        }

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

            var destination = destinationIndexPath.item
            if sourceIndexPath.item < destination {
                destination += 1
            }

            parent.onReorder(IndexSet(integer: sourceIndexPath.item), destination)
            coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
            parent.isDraggingTask = false
            parent.dragItemID = nil
        }
    }
}
