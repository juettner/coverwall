import XCTest
@testable import CoverwallShared

final class TokenStoreTests: XCTestCase {
    private let store = TokenStore(service: "com.chadjuettner.coverwall.tests",
                                   account: "unit-\(UUID().uuidString)")

    override func tearDown() {
        store.delete()
        super.tearDown()
    }

    func testLoadEmptyReturnsNil() {
        XCTAssertNil(store.load())
    }

    func testSaveLoadDelete() throws {
        let tokens = TokenSet(accessToken: "AT", refreshToken: "RT",
                              expiresAt: Date(timeIntervalSince1970: 2000))
        try store.save(tokens)
        XCTAssertEqual(store.load(), tokens)

        let updated = TokenSet(accessToken: "AT2", refreshToken: "RT",
                               expiresAt: Date(timeIntervalSince1970: 3000))
        try store.save(updated)
        XCTAssertEqual(store.load(), updated)

        store.delete()
        XCTAssertNil(store.load())
    }
}
