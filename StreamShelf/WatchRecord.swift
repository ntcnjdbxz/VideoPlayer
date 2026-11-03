import Foundation

struct WatchRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var pageURL: String
    var playerURL: String?
    var title: String
    var season: Int?
    var episode: Int?
    var positionSeconds: Double = 0
    var durationSeconds: Double?
    var lastWatched: Date = .now
    var isFavorite: Bool = false

    var progressText: String { Self.time(positionSeconds) }

    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let n = Int(seconds), h = n / 3600, m = (n % 3600) / 60, s = n % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
