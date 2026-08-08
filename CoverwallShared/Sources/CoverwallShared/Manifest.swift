import Foundation

public struct AlbumArt: Codable, Equatable, Identifiable {
    public var id: String { albumID }
    public let albumID: String
    public let title: String
    public let artist: String
    public let imageFilename: String
    public let addedAt: Date

    public init(albumID: String, title: String, artist: String,
                imageFilename: String, addedAt: Date) {
        self.albumID = albumID
        self.title = title
        self.artist = artist
        self.imageFilename = imageFilename
        self.addedAt = addedAt
    }
}

public struct Manifest: Codable, Equatable {
    public static let currentVersion = 1

    public let version: Int
    public let source: ArtSource
    public let updatedAt: Date
    public let albums: [AlbumArt]

    public init(version: Int = Manifest.currentVersion, source: ArtSource,
                updatedAt: Date, albums: [AlbumArt]) {
        self.version = version
        self.source = source
        self.updatedAt = updatedAt
        self.albums = albums
    }
}

public struct ManifestStore {
    private let url: URL

    public init(url: URL = SharedPaths.manifestURL) {
        self.url = url
    }

    public func write(_ manifest: Manifest) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    public func read() -> Manifest? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Manifest.self, from: data)
    }

    public var lastModified: Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
