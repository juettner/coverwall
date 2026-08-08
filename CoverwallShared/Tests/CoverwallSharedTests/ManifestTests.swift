import XCTest
@testable import CoverwallShared

final class ManifestTests: XCTestCase {
    private var url: URL!
    private var store: ManifestStore!

    override func setUp() {
        super.setUp()
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("manifest-\(UUID().uuidString).json")
        store = ManifestStore(url: url)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        super.tearDown()
    }

    private func sample() -> Manifest {
        Manifest(version: 1, source: .recentlyPlayed, updatedAt: Date(timeIntervalSince1970: 1000),
                 albums: [AlbumArt(albumID: "abc", title: "Blue", artist: "Joni Mitchell",
                                   imageFilename: "abc.jpg", addedAt: Date(timeIntervalSince1970: 900))])
    }

    func testRoundTrip() throws {
        try store.write(sample())
        XCTAssertEqual(store.read(), sample())
    }

    func testReadMissingReturnsNil() {
        XCTAssertNil(store.read())
    }

    func testReadCorruptReturnsNil() throws {
        try Data("not json".utf8).write(to: url)
        XCTAssertNil(store.read())
    }

    func testLastModified() throws {
        XCTAssertNil(store.lastModified)
        try store.write(sample())
        XCTAssertNotNil(store.lastModified)
    }
}
