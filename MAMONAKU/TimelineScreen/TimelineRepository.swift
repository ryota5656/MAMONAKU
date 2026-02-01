//
//  TimelineRepository.swift
//  MAMONAKU
//
//  Created by ryota.saito on 2026/01/25.
//
import Foundation

protocol TimelineRepositoryProtocol: AnyObject {
    func fetchItems() -> [TimelineItem]
    func saveItems(_ items: [TimelineItem])
    func addItem(_ item: TimelineItem)
    func updateItem(_ item: TimelineItem)
    func deleteItem(id: UUID)
}

final class TimelineRepository: TimelineRepositoryProtocol {
    private let storageKey = "timeline_items"
    private let appGroupID = "group.sairyo.MAMONAKU"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults? = nil) {
        if let userDefaults {
            self.userDefaults = userDefaults
        } else {
            self.userDefaults = UserDefaults(suiteName: appGroupID) ?? .standard
        }
    }

    func fetchItems() -> [TimelineItem] {
        loadItems()
    }

    func saveItems(_ items: [TimelineItem]) {
        persist(items)
    }

    func addItem(_ item: TimelineItem) {
        var items = loadItems()
        items.append(item)
        persist(items)
    }

    func updateItem(_ item: TimelineItem) {
        var items = loadItems()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        persist(items)
    }

    func deleteItem(id: UUID) {
        var items = loadItems()
        items.removeAll { $0.id == id }
        persist(items)
    }

    private func loadItems() -> [TimelineItem] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([TimelineItem].self, from: data)
        } catch {
            return []
        }
    }

    private func persist(_ items: [TimelineItem]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            userDefaults.set(data, forKey: storageKey)
            print(data)
        } catch {
            print("😭保存に失敗しました")
        }
    }
}
