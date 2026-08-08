import XCTest
@testable import CoverwallShared

final class SharedSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: SharedSettings!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.coverwall.settings")!
        defaults.removePersistentDomain(forName: "test.coverwall.settings")
        settings = SharedSettings(defaults: defaults)
    }

    func testDefaults() {
        XCTAssertEqual(settings.artSource, .recentlyPlayed)
        XCTAssertEqual(settings.topTracksRange, .mediumTerm)
        XCTAssertEqual(settings.tileDensity, .medium)
        XCTAssertEqual(settings.flipInterval, 4.0)
        XCTAssertFalse(settings.showLabels)
    }

    func testRoundTrip() {
        settings.artSource = .likedSongs
        settings.flipInterval = 9.5
        settings.showLabels = true
        let reread = SharedSettings(defaults: defaults)
        XCTAssertEqual(reread.artSource, .likedSongs)
        XCTAssertEqual(reread.flipInterval, 9.5)
        XCTAssertTrue(reread.showLabels)
    }

    func testFlipIntervalClamped() {
        settings.flipInterval = 60
        XCTAssertEqual(settings.flipInterval, 15)
        settings.flipInterval = 0.5
        XCTAssertEqual(settings.flipInterval, 2)
    }

    func testPathsExist() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: SharedPaths.imagesDirectory.path))
        XCTAssertEqual(SharedPaths.manifestURL.lastPathComponent, "manifest.json")
    }
}
