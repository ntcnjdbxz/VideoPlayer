import Foundation
import Combine

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [WatchRecord] = []
    @Published var lastRecordID: UUID?

    private let key = "StreamShelf.history.v1"
    private let lastKey = "StreamShelf.lastID.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([WatchRecord].self, from: data) {
            records = decoded.sorted { $0.lastWatched > $1.lastWatched }
        }
        if let value = UserDefaults.standard.string(forKey: lastKey) {
            lastRecordID = UUID(uuidString: value)
        }
    }

    var lastRecord: WatchRecord? {
        if let id = lastRecordID, let found = records.first(where: { $0.id == id }) { return found }
        return records.first
    }

    func upsert(_ input: WatchRecord) {
        var item = input
        item.lastWatched = .now
        if let index = records.firstIndex(where: { $0.pageURL == item.pageURL }) {
            let old = records[index]
            item.id = old.id
            item.isFavorite = old.isFavorite
            if item.playerURL == nil { item.playerURL = old.playerURL }
            if item.title.isEmpty { item.title = old.title }
            if item.positionSeconds == 0 { item.positionSeconds = old.positionSeconds }
            if item.season == nil { item.season = old.season }
            if item.episode == nil { item.episode = old.episode }
            records[index] = item
        } else {
            records.insert(item, at: 0)
        }
        records.sort { $0.lastWatched > $1.lastWatched }
        lastRecordID = item.id
        save()
    }

    func progress(pageURL: String, playerURL: String?, title: String, season: Int?, episode: Int?,
                  position: Double, duration: Double?) {
        guard let index = records.firstIndex(where: { $0.pageURL == pageURL }) else { return }
        var item = records[index]
        if let playerURL, !playerURL.isEmpty { item.playerURL = playerURL }
        if !title.isEmpty { item.title = title }
        if let season { item.season = season }
        if let episode { item.episode = episode }
        if position.isFinite && position >= 0 { item.positionSeconds = position }
        if let duration, duration.isFinite && duration > 0 { item.durationSeconds = duration }
        item.lastWatched = .now
        records[index] = item
        records.sort { $0.lastWatched > $1.lastWatched }
        lastRecordID = item.id
        save()
    }

    func toggleFavorite(_ item: WatchRecord) {
        guard let i = records.firstIndex(where: { $0.id == item.id }) else { return }
        records[i].isFavorite.toggle()
        save()
    }

    func delete(_ item: WatchRecord) {
        records.removeAll { $0.id == item.id }
        if lastRecordID == item.id { lastRecordID = records.first?.id }
        save()
    }

    func clear() {
        records = []
        lastRecordID = nil
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) { UserDefaults.standard.set(data, forKey: key) }
        UserDefaults.standard.set(lastRecordID?.uuidString, forKey: lastKey)
    }
}
