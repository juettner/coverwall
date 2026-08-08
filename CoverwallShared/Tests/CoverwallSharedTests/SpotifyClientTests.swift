import XCTest
@testable import CoverwallShared

final class SpotifyClientTests: XCTestCase {
    private var client: SpotifyClient!

    override func setUp() {
        super.setUp()
        client = SpotifyClient(session: MockURLProtocol.session())
    }

    func testExchangeCodeParsesTokens() async throws {
        MockURLProtocol.respond(json: #"""
        {"access_token":"AT","refresh_token":"RT","expires_in":3600,"token_type":"Bearer"}
        """#)
        let tokens = try await client.exchangeCode("code123", verifier: "ver")
        XCTAssertEqual(tokens.accessToken, "AT")
        XCTAssertEqual(tokens.refreshToken, "RT")
        XCTAssertFalse(tokens.isExpired)
    }

    func testRefreshKeepsOldRefreshTokenWhenAbsent() async throws {
        MockURLProtocol.respond(json: #"""
        {"access_token":"AT2","expires_in":3600,"token_type":"Bearer"}
        """#)
        let old = TokenSet(accessToken: "AT", refreshToken: "RT",
                           expiresAt: Date(timeIntervalSinceNow: -10))
        let refreshed = try await client.refresh(old)
        XCTAssertEqual(refreshed.accessToken, "AT2")
        XCTAssertEqual(refreshed.refreshToken, "RT")
    }

    func testRecentlyPlayedDedupesAlbums() async throws {
        MockURLProtocol.respond(json: #"""
        {"items":[
          {"track":{"album":{"id":"al1","name":"Blue","images":[{"url":"https://img/al1-640","width":640,"height":640},{"url":"https://img/al1-300","width":300,"height":300}],"artists":[{"name":"Joni Mitchell"}]}}},
          {"track":{"album":{"id":"al1","name":"Blue","images":[{"url":"https://img/al1-640","width":640,"height":640}],"artists":[{"name":"Joni Mitchell"}]}}},
          {"track":{"album":{"id":"al2","name":"Kind of Blue","images":[{"url":"https://img/al2-640","width":640,"height":640}],"artists":[{"name":"Miles Davis"}]}}}
        ]}
        """#)
        let albums = try await client.recentlyPlayed(accessToken: "AT")
        XCTAssertEqual(albums.map(\.albumID), ["al1", "al2"])
        XCTAssertEqual(albums[0].imageURL.absoluteString, "https://img/al1-640")
        XCTAssertEqual(albums[0].artist, "Joni Mitchell")
    }

    func testRateLimitedThrowsRetryAfter() async {
        MockURLProtocol.respond(status: 429, json: "{}", headers: ["Retry-After": "7"])
        do {
            _ = try await client.recentlyPlayed(accessToken: "AT")
            XCTFail("expected throw")
        } catch let SpotifyError.rateLimited(retryAfter) {
            XCTAssertEqual(retryAfter, 7)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testTopTracksUsesRangeParameter() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        MockURLProtocol.handler = { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"items":[]}"#.utf8))
        }
        _ = try await client.topTracks(range: .longTerm, accessToken: "AT")
        XCTAssertTrue(captured!.url!.query!.contains("time_range=long_term"))
        XCTAssertEqual(captured!.value(forHTTPHeaderField: "Authorization"), "Bearer AT")
    }

    func testExchangeCodeEncodesReservedCharactersInBody() async throws {
        nonisolated(unsafe) var capturedBody: String?
        MockURLProtocol.handler = { request in
            var bodyData = request.httpBody ?? Data()
            if bodyData.isEmpty, let stream = request.httpBodyStream {
                stream.open()
                var buffer = [UInt8](repeating: 0, count: 1024)
                var totalData = Data()
                while stream.hasBytesAvailable {
                    let bytesRead = stream.read(&buffer, maxLength: buffer.count)
                    if bytesRead > 0 {
                        totalData.append(buffer, count: bytesRead)
                    }
                }
                stream.close()
                bodyData = totalData
            }
            capturedBody = String(data: bodyData, encoding: .utf8) ?? ""
            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"access_token":"AT","refresh_token":"RT","expires_in":3600}"#.utf8))
        }
        _ = try await client.exchangeCode("ab+c&d=e", verifier: "ver")
        XCTAssertTrue(capturedBody!.contains("code=ab%2Bc%26d%3De"),
                      "Body should contain percent-encoded code; got: \(capturedBody!)")
        XCTAssertFalse(capturedBody!.contains("ab+c"),
                       "Body should not contain unencoded reserved characters; got: \(capturedBody!)")
    }
}
