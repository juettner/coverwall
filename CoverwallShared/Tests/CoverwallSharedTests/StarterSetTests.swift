import XCTest
@testable import CoverwallShared

final class StarterSetTests: XCTestCase {
    func testCuratedListIsSubstantialAndUnique() {
        XCTAssertGreaterThanOrEqual(StarterSet.tracks.count, 40)
        XCTAssertEqual(Set(StarterSet.tracks.map(\.trackID)).count, StarterSet.tracks.count)
        for track in StarterSet.tracks {
            XCTAssertFalse(track.trackID.isEmpty)
            XCTAssertFalse(track.artist.isEmpty)
            XCTAssertFalse(track.title.isEmpty)
        }
    }

    func testOEmbedCoverURLParsing() async throws {
        MockURLProtocol.respond(json: #"""
        {"title":"petal","thumbnail_url":"https://i.scdn.co/image/ab67616d0000b273abc123","provider_name":"Spotify"}
        """#)
        let client = StarterArtClient(session: MockURLProtocol.session())
        let url = try await client.coverURL(forTrackID: "70pVCVMGjmIWPbWXDwf11e")
        XCTAssertEqual(url.absoluteString, "https://i.scdn.co/image/ab67616d0000b273abc123")
    }

    func testOEmbedMissingThumbnailThrows() async {
        MockURLProtocol.respond(json: #"{"title":"x","provider_name":"Spotify"}"#)
        let client = StarterArtClient(session: MockURLProtocol.session())
        do {
            _ = try await client.coverURL(forTrackID: "abc")
            XCTFail("expected throw")
        } catch {
            // expected
        }
    }
}
