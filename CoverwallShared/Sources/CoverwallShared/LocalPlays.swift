import CryptoKit
import Foundation

/// One observed play from the Spotify desktop app, captured via its
/// distributed PlaybackStateChanged notification — no API, no login.
public struct LocalPlay: Codable, Equatable {
    public let trackID: String
    public let title: String
    public let artist: String
    public let album: String
    public let playedAt: Date

    public init(trackID: String, title: String, artist: String,
                album: String, playedAt: Date) {
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.album = album
        self.playedAt = playedAt
    }

    /// Parses Spotify's com.spotify.client.PlaybackStateChanged userInfo.
    /// Returns nil unless something is actually playing (ads excluded).
    public static func from(notificationUserInfo info: [AnyHashable: Any],
                            at date: Date = Date()) -> LocalPlay? {
        guard let state = info["Player State"] as? String, state == "Playing",
              let rawID = info["Track ID"] as? String,
              rawID.hasPrefix("spotify:track:"),
              let title = info["Name"] as? String,
              let artist = info["Artist"] as? String,
              let album = info["Album"] as? String else { return nil }
        return LocalPlay(trackID: String(rawID.dropFirst("spotify:track:".count)),
                         title: title, artist: artist, album: album, playedAt: date)
    }
}

/// Persists observed plays as JSON (newest first), consecutive-deduped and
/// capped. Single-writer (the helper app); the saver never reads this —
/// plays reach it through the normal manifest pipeline.
public struct LocalPlaysStore {
    public static let cap = 300

    private let url: URL

    public init(url: URL = SharedPaths.containerURL.appendingPathComponent("local-plays.json")) {
        self.url = url
    }

    public func record(_ play: LocalPlay) {
        var plays = recentPlays()
        if let last = plays.first, last.trackID == play.trackID {
            plays[0] = play  // same track re-reported (seek/pause): refresh timestamp
        } else {
            plays.insert(play, at: 0)
        }
        write(Array(plays.prefix(Self.cap)))
    }

    public func recentPlays() -> [LocalPlay] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([LocalPlay].self, from: data)) ?? []
    }

    public func distinctAlbumCount() -> Int {
        Set(recentPlays().map { albumKey(artist: $0.artist, album: $0.album) }).count
    }

    public func albumKey(artist: String, album: String) -> String {
        "\(artist)|\(album)".lowercased()
    }

    /// Deterministic cache-friendly album ID (Swift's hashValue is salted
    /// per process, so hash explicitly).
    public func stableAlbumID(forKey key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "local-" + String(hex.prefix(16))
    }

    private func write(_ plays: [LocalPlay]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(plays) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
