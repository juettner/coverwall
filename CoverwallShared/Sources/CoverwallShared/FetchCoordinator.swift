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
        /// Not logged in, but the curated starter chart is on display.
        case starter(albumCount: Int)
        case notLoggedIn
        case failed(String)
    }

    private let client: SpotifyFetching
    private let tokens: TokenStoring
    private let cache: CacheStore
    private let manifests: ManifestStore
    private let settings: SharedSettings
    private let starter: StarterArtFetching

    public init(client: SpotifyFetching, tokens: TokenStoring, cache: CacheStore,
                manifests: ManifestStore, settings: SharedSettings,
                starter: StarterArtFetching = StarterArtClient()) {
        self.client = client
        self.tokens = tokens
        self.cache = cache
        self.manifests = manifests
        self.settings = settings
        self.starter = starter
    }

    public func refresh() async -> RefreshOutcome {
        guard var tokenSet = tokens.load() else { return await refreshStarterIfNeeded() }
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
            case .starter:
                // Never a user-selectable setting; treat defensively as the default.
                refs = try await client.recentlyPlayed(accessToken: tokenSet.accessToken)
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

    /// Pre-login: fill the screen with the baked-in global chart snapshot so
    /// a fresh install never shows the gradient placeholder. Runs only when
    /// no manifest exists at all — a logged-out user keeps whatever art they
    /// last had, and a logged-in refresh replaces starter art wholesale.
    private func refreshStarterIfNeeded() async -> RefreshOutcome {
        guard manifests.read() == nil else { return .notLoggedIn }

        var albums: [AlbumArt] = []
        var seenCovers = Set<URL>()
        for track in StarterSet.tracks {
            guard let coverURL = try? await starter.coverURL(forTrackID: track.trackID),
                  seenCovers.insert(coverURL).inserted else { continue }
            let albumID = "starter-\(track.trackID)"
            if !cache.contains(albumID: albumID) {
                guard let data = try? await starter.downloadImage(at: coverURL) else { continue }
                guard (try? cache.store(data, albumID: albumID)) != nil else { continue }
            }
            albums.append(AlbumArt(albumID: albumID, title: track.title,
                                   artist: track.artist,
                                   imageFilename: cache.filename(forAlbumID: albumID),
                                   addedAt: Date()))
        }

        guard !albums.isEmpty else { return .notLoggedIn }
        do {
            try manifests.write(Manifest(source: .starter, updatedAt: Date(), albums: albums))
        } catch {
            return .notLoggedIn
        }
        cache.prune(keeping: albums.map(\.albumID))
        return .starter(albumCount: albums.count)
    }
}
