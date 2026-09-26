import Foundation

public enum ArtSource: String, Codable, CaseIterable {
    case recentlyPlayed, topTracks, likedSongs
    /// Pre-login curated chart snapshot; never user-selectable, appears only
    /// as a Manifest.source written by the starter-art path.
    case starter
}

public enum TopTracksRange: String, Codable, CaseIterable {
    case shortTerm, mediumTerm, longTerm

    public var apiValue: String {
        switch self {
        case .shortTerm: "short_term"
        case .mediumTerm: "medium_term"
        case .longTerm: "long_term"
        }
    }
}

public enum TileDensity: String, Codable, CaseIterable {
    case small, medium, large

    public var approximateTileWidth: CGFloat {
        switch self {
        case .small: 120
        case .medium: 200
        case .large: 280
        }
    }
}

public struct SharedSettings {
    public static let suiteName = "group.com.chadjuettner.coverwall"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard) {
        self.defaults = defaults
    }

    public var artSource: ArtSource {
        get { defaults.string(forKey: "artSource").flatMap(ArtSource.init) ?? .recentlyPlayed }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "artSource") }
    }

    public var topTracksRange: TopTracksRange {
        get { defaults.string(forKey: "topTracksRange").flatMap(TopTracksRange.init) ?? .mediumTerm }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "topTracksRange") }
    }

    public var tileDensity: TileDensity {
        get { defaults.string(forKey: "tileDensity").flatMap(TileDensity.init) ?? .medium }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "tileDensity") }
    }

    public var flipInterval: Double {
        get {
            let raw = defaults.object(forKey: "flipInterval") as? Double ?? 4.0
            return min(max(raw, 2), 15)
        }
        nonmutating set { defaults.set(min(max(newValue, 2), 15), forKey: "flipInterval") }
    }

    public var showLabels: Bool {
        get { defaults.bool(forKey: "showLabels") }
        nonmutating set { defaults.set(newValue, forKey: "showLabels") }
    }

    /// A user-supplied Spotify Client ID ("bring your own app"), which lifts
    /// Spotify's per-app development-mode user cap: each user owns their own
    /// allowlist-of-one. nil/blank means use the built-in app.
    public var customClientID: String? {
        get {
            let raw = defaults.string(forKey: "customClientID")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return raw.isEmpty ? nil : raw
        }
        nonmutating set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                defaults.removeObject(forKey: "customClientID")
            } else {
                defaults.set(trimmed, forKey: "customClientID")
            }
        }
    }
}
