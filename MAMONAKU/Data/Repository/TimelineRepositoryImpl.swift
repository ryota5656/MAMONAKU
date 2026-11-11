import Foundation

/// 予定を Realm に保存し、標準カレンダー同期（`CalendarSyncClient`）へ変更を伝える。
///
/// 保存のたびに予定一覧の JSON を App Group の UserDefaults にも書き出す（ミラー）。
/// ミラーは Realm が空のとき（旧バージョンからの移行や Realm ファイル消失時）の復元元になる。
nonisolated final class TimelineRepositoryImpl: TimelineRepository {
    private let realmClient: TimelineRealmClient
    private let settings: AppSettingsClient
    private let calendarSync: CalendarSyncClient

    init(
        realmClient: TimelineRealmClient,
        settings: AppSettingsClient,
        calendarSync: CalendarSyncClient
    ) {
        self.realmClient = realmClient
        self.settings = settings
        self.calendarSync = calendarSync

        // カレンダーからの取り込みで Realm が変わったら、ミラーも追従させる。
        calendarSync.onItemsImported = { [weak self] in
            guard let self else { return }
            self.writeMirror(self.realmClient.fetchItems())
        }
        restoreFromMirrorIfNeeded()
        calendarSync.start()
    }

    func fetchItems() -> [TimelineItem] {
        realmClient.fetchItems()
    }

    func saveItems(_ items: [TimelineItem]) {
        replaceItems(with: items)
    }

    func deleteItem(id: UUID) {
        let result = realmClient.deleteItem(id: id)
        guard result.success else { return }

        if let eventIdentifier = result.eventIdentifier {
            calendarSync.deleteEventsInBackground(identifiers: [eventIdentifier])
        }
        writeMirror(realmClient.fetchItems())
    }

    func requestCalendarAccess() async -> Bool {
        await calendarSync.requestFullAccess()
    }

    func setCalendarSyncEnabled(_ enabled: Bool) {
        settings.isCalendarSyncPreferred = enabled
        calendarSync.preferenceDidChange(isEnabled: enabled)
    }

    // MARK: - Private

    private func replaceItems(with items: [TimelineItem]) {
        let removedEventIdentifiers = realmClient.replaceAll(with: items)
        calendarSync.deleteEvents(identifiers: removedEventIdentifiers)
        calendarSync.exportItemsToCalendar()
        writeMirror(items)
    }

    // MARK: - JSON ミラー

    private func restoreFromMirrorIfNeeded() {
        guard realmClient.isEmpty() else { return }
        guard let data = settings.defaults.data(forKey: AppGroup.timelineItemsMirrorKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let items = try? decoder.decode([TimelineItem].self, from: data) else { return }
        replaceItems(with: items)
    }

    private func writeMirror(_ items: [TimelineItem]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        settings.defaults.set(data, forKey: AppGroup.timelineItemsMirrorKey)
    }
}
