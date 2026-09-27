import XCTest
@testable import CoverwallShared

final class LocalPlaysTests: XCTestCase {
    private var url: URL!
    private var store: LocalPlaysStore!

    override func setUp() {
        super.setUp()
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plays-\(UUID().uuidString).json")
        store = LocalPlaysStore(url: url)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        super.tearDown()
    }

    private func play(_ id: String, album: String = "A", at t: TimeInterval = 0) -> LocalPlay {
        LocalPlay(trackID: id, title: "T-\(id)", artist: "Artist", album: album,
                  playedAt: Date(timeIntervalSince1970: t))
    }

    func testRecordAndPersist() {
        store.record(play("t1", at: 100))
        store.record(play("t2", album: "B", at: 200))
        let reread = LocalPlaysStore(url: url)
        XCTAssertEqual(reread.recentPlays().map(\.trackID), ["t2", "t1"])
    }

    func testConsecutiveSameTrackUpdatesInsteadOfAppending() {
        store.record(play("t1", at: 100))
        store.record(play("t1", at: 250))
        XCTAssertEqual(store.recentPlays().count, 1)
        XCTAssertEqual(store.recentPlays().first?.playedAt,
                       Date(timeIntervalSince1970: 250))
    }

    func testCapDropsOldest() {
        for i in 0..<310 {
            store.record(play("t\(i)", at: TimeInterval(i)))
        }
        let plays = store.recentPlays()
        XCTAssertEqual(plays.count, 300)
        XCTAssertEqual(plays.first?.trackID, "t309")
        XCTAssertFalse(plays.contains { $0.trackID == "t0" })
    }

    func testDistinctAlbumCount() {
        store.record(play("t1", album: "A", at: 1))
        store.record(play("t2", album: "B", at: 2))
        store.record(play("t3", album: "a", at: 3))  // same album, case-insensitive
        XCTAssertEqual(store.distinctAlbumCount(), 2)
    }

    // MARK: - Notification parsing

    func testParsePlayingNotification() {
        let userInfo: [AnyHashable: Any] = [
            "Player State": "Playing",
            "Track ID": "spotify:track:1Qyt1vzKvsNlZhMepIxpbo",
            "Name": "Cause",
            "Artist": "Rodríguez",
            "Album": "Coming From Reality",
        ]
        let play = LocalPlay.from(notificationUserInfo: userInfo,
                                  at: Date(timeIntervalSince1970: 42))
        XCTAssertEqual(play?.trackID, "1Qyt1vzKvsNlZhMepIxpbo")
        XCTAssertEqual(play?.title, "Cause")
        XCTAssertEqual(play?.artist, "Rodríguez")
        XCTAssertEqual(play?.album, "Coming From Reality")
        XCTAssertEqual(play?.playedAt, Date(timeIntervalSince1970: 42))
    }

    func testParseIgnoresPausedAndAds() {
        var userInfo: [AnyHashable: Any] = [
            "Player State": "Paused",
            "Track ID": "spotify:track:abc",
            "Name": "X", "Artist": "Y", "Album": "Z",
        ]
        XCTAssertNil(LocalPlay.from(notificationUserInfo: userInfo, at: Date()))

        userInfo["Player State"] = "Playing"
        userInfo["Track ID"] = "spotify:ad:12345"
        XCTAssertNil(LocalPlay.from(notificationUserInfo: userInfo, at: Date()))

        userInfo["Track ID"] = nil
        XCTAssertNil(LocalPlay.from(notificationUserInfo: userInfo, at: Date()))
    }
}
