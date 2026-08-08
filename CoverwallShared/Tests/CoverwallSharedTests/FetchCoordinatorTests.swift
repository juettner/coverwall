import XCTest
@testable import CoverwallShared

private final class StubClient: SpotifyFetching {
    var albums: [AlbumRef] = []
    var refreshed = false
    var failDownloads: Set<String> = []
    var refreshError: Error?

    func refresh(_ token: TokenSet) async throws -> TokenSet {
        refreshed = true
        if let refreshError { throw refreshError }
        return TokenSet(accessToken: "fresh", refreshToken: token.refreshToken,
                        expiresAt: Date(timeIntervalSinceNow: 3600))
    }
    func recentlyPlayed(accessToken: String) async throws -> [AlbumRef] { albums }
    func topTracks(range: TopTracksRange, accessToken: String) async throws -> [AlbumRef] { albums }
    func likedSongs(accessToken: String, pages: Int) async throws -> [AlbumRef] { albums }
    func downloadImage(at url: URL) async throws -> Data {
        if failDownloads.contains(url.absoluteString) { throw SpotifyError.http(404) }
        return Data([0xFF])
    }
}

private final class StubTokens: TokenStoring {
    var stored: TokenSet?
    func load() -> TokenSet? { stored }
    func save(_ tokens: TokenSet) throws { stored = tokens }
    func delete() { stored = nil }
}

final class FetchCoordinatorTests: XCTestCase {
    private var dir: URL!
    private var cacheDir: URL!
    private var client: StubClient!
    private var tokens: StubTokens!
    private var coordinator: FetchCoordinator!
    private var manifests: ManifestStore!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fetch-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheDir = dir.appendingPathComponent("images", isDirectory: true)
        try! FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        client = StubClient()
        tokens = StubTokens()
        manifests = ManifestStore(url: dir.appendingPathComponent("manifest.json"))
        let suite = UserDefaults(suiteName: "test.coverwall.fetch")!
        suite.removePersistentDomain(forName: "test.coverwall.fetch")
        coordinator = FetchCoordinator(client: client, tokens: tokens,
                                       cache: CacheStore(directory: cacheDir),
                                       manifests: manifests,
                                       settings: SharedSettings(defaults: suite))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func album(_ id: String) -> AlbumRef {
        AlbumRef(albumID: id, title: "T-\(id)", artist: "A",
                 imageURL: URL(string: "https://img/\(id)")!)
    }

    func testNotLoggedIn() async {
        let outcome = await coordinator.refresh()
        XCTAssertEqual(outcome, .notLoggedIn)
        XCTAssertNil(manifests.read())
    }

    func testRefreshWritesManifestAndImages() async {
        tokens.stored = TokenSet(accessToken: "AT", refreshToken: "RT",
                                 expiresAt: Date(timeIntervalSinceNow: 3600))
        client.albums = [album("a1"), album("a2")]
        let outcome = await coordinator.refresh()
        XCTAssertEqual(outcome, .updated(albumCount: 2))
        let manifest = manifests.read()
        XCTAssertEqual(manifest?.albums.map(\.albumID), ["a1", "a2"])
        XCTAssertTrue(CacheStore(directory: cacheDir).contains(albumID: "a1"))
        XCTAssertFalse(client.refreshed)
    }

    func testExpiredTokenIsRefreshedAndPersisted() async {
        tokens.stored = TokenSet(accessToken: "old", refreshToken: "RT",
                                 expiresAt: Date(timeIntervalSinceNow: -100))
        client.albums = [album("a1")]
        _ = await coordinator.refresh()
        XCTAssertTrue(client.refreshed)
        XCTAssertEqual(tokens.stored?.accessToken, "fresh")
    }

    func testFailedDownloadSkipsAlbum() async {
        tokens.stored = TokenSet(accessToken: "AT", refreshToken: "RT",
                                 expiresAt: Date(timeIntervalSinceNow: 3600))
        client.albums = [album("good"), album("bad")]
        client.failDownloads = ["https://img/bad"]
        let outcome = await coordinator.refresh()
        XCTAssertEqual(outcome, .updated(albumCount: 1))
        XCTAssertEqual(manifests.read()?.albums.map(\.albumID), ["good"])
    }

    func testRevokedRefreshTokenLogsOut() async {
        tokens.stored = TokenSet(accessToken: "old", refreshToken: "RT",
                                 expiresAt: Date(timeIntervalSinceNow: -100))
        client.refreshError = SpotifyError.http(400)
        let outcome = await coordinator.refresh()
        XCTAssertEqual(outcome, .notLoggedIn)
        XCTAssertNil(tokens.stored)
    }

    func testSecondRefreshEvictsDroppedAlbumsAndKeepsManifestReadable() async {
        tokens.stored = TokenSet(accessToken: "AT", refreshToken: "RT",
                                 expiresAt: Date(timeIntervalSinceNow: 3600))

        // First refresh with albums a1, a2
        client.albums = [album("a1"), album("a2")]
        let outcome1 = await coordinator.refresh()
        XCTAssertEqual(outcome1, .updated(albumCount: 2))
        XCTAssertEqual(manifests.read()?.albums.map(\.albumID), ["a1", "a2"])
        XCTAssertTrue(CacheStore(directory: cacheDir).contains(albumID: "a1"))
        XCTAssertTrue(CacheStore(directory: cacheDir).contains(albumID: "a2"))

        // Second refresh with albums a2, a3 (a1 dropped, a3 is new)
        client.albums = [album("a2"), album("a3")]
        let outcome2 = await coordinator.refresh()
        XCTAssertEqual(outcome2, .updated(albumCount: 2))

        // Manifest should reflect new set
        let manifest = manifests.read()
        XCTAssertEqual(manifest?.albums.map(\.albumID), ["a2", "a3"])

        // Cache should have a2, a3 but not a1 (evicted by prune)
        let cache = CacheStore(directory: cacheDir)
        XCTAssertFalse(cache.contains(albumID: "a1"))
        XCTAssertTrue(cache.contains(albumID: "a2"))
        XCTAssertTrue(cache.contains(albumID: "a3"))
    }
}
