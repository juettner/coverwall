import XCTest
@testable import CoverwallShared

final class CacheStoreTests: XCTestCase {
    private var dir: URL!
    private var cache: CacheStore!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cache = CacheStore(directory: dir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    func testStoreAndContains() throws {
        XCTAssertFalse(cache.contains(albumID: "a1"))
        try cache.store(Data([1, 2, 3]), albumID: "a1")
        XCTAssertTrue(cache.contains(albumID: "a1"))
        XCTAssertEqual(cache.filename(forAlbumID: "a1"), "a1.jpg")
    }

    func testPruneRemovesUnreferenced() throws {
        try cache.store(Data([1]), albumID: "keep")
        try cache.store(Data([2]), albumID: "drop")
        cache.prune(keeping: ["keep"])
        XCTAssertTrue(cache.contains(albumID: "keep"))
        XCTAssertFalse(cache.contains(albumID: "drop"))
    }

    func testPruneEnforcesCap() throws {
        for i in 0..<5 { try cache.store(Data([UInt8(i)]), albumID: "a\(i)") }
        cache.prune(keeping: (0..<5).map { "a\($0)" }, cap: 3)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertEqual(remaining.count, 3)
    }
}
