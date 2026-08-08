import Foundation

public protocol SpotifyFetching {
    func refresh(_ token: TokenSet) async throws -> TokenSet
    func recentlyPlayed(accessToken: String) async throws -> [AlbumRef]
    func topTracks(range: TopTracksRange, accessToken: String) async throws -> [AlbumRef]
    func likedSongs(accessToken: String, pages: Int) async throws -> [AlbumRef]
    func downloadImage(at url: URL) async throws -> Data
}

extension SpotifyClient: SpotifyFetching {}

public protocol TokenStoring {
    func load() -> TokenSet?
    func save(_ tokens: TokenSet) throws
    func delete()
}

extension TokenStore: TokenStoring {}

public struct FetchCoordinator {
    public enum RefreshOutcome: Equatable {
        case updated(albumCount: Int)
        case notLoggedIn
        case failed(String)
    }

    private let client: SpotifyFetching
    private let tokens: TokenStoring
    private let cache: CacheStore
    private let manifests: ManifestStore
    private let settings: SharedSettings

    public init(client: SpotifyFetching, tokens: TokenStoring, cache: CacheStore,
                manifests: ManifestStore, settings: SharedSettings) {
        self.client = client
        self.tokens = tokens
        self.cache = cache
        self.manifests = manifests
        self.settings = settings
    }

    public func refresh() async -> RefreshOutcome {
        guard var tokenSet = tokens.load() else { return .notLoggedIn }
        do {
            if tokenSet.isExpired {
                do {
                    tokenSet = try await client.refresh(tokenSet)
                    try tokens.save(tokenSet)
                } catch SpotifyError.http(400), SpotifyError.http(401) {
                    tokens.delete()
                    return .notLoggedIn
                }
            }

            let refs: [AlbumRef]
            switch settings.artSource {
            case .recentlyPlayed:
                refs = try await client.recentlyPlayed(accessToken: tokenSet.accessToken)
            case .topTracks:
                refs = try await client.topTracks(range: settings.topTracksRange,
                                                  accessToken: tokenSet.accessToken)
            case .likedSongs:
                refs = try await client.likedSongs(accessToken: tokenSet.accessToken, pages: 4)
            }

            var albums: [AlbumArt] = []
            for ref in refs {
                if !cache.contains(albumID: ref.albumID) {
                    guard let data = try? await client.downloadImage(at: ref.imageURL) else {
                        continue
                    }
                    try cache.store(data, albumID: ref.albumID)
                }
                albums.append(AlbumArt(albumID: ref.albumID, title: ref.title,
                                       artist: ref.artist,
                                       imageFilename: cache.filename(forAlbumID: ref.albumID),
                                       addedAt: Date()))
            }

            try manifests.write(Manifest(source: settings.artSource,
                                         updatedAt: Date(), albums: albums))
            cache.prune(keeping: albums.map(\.albumID))
            return .updated(albumCount: albums.count)
        } catch {
            return .failed(String(describing: error))
        }
    }
}
