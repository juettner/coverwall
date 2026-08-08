import XCTest
@testable import CoverwallShared

final class PKCETests: XCTestCase {
    func testKnownVector() {
        // RFC 7636 appendix B test vector
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        XCTAssertEqual(PKCE.challenge(for: verifier),
                       "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testGeneratedShape() {
        let pkce = PKCE()
        XCTAssertGreaterThanOrEqual(pkce.verifier.count, 43)
        XCTAssertLessThanOrEqual(pkce.verifier.count, 128)
        XCTAssertFalse(pkce.verifier.contains("="))
        XCTAssertFalse(pkce.challenge.contains("="))
        XCTAssertEqual(PKCE.challenge(for: pkce.verifier), pkce.challenge)
    }

    func testUnique() {
        XCTAssertNotEqual(PKCE().verifier, PKCE().verifier)
    }
}
