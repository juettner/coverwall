import XCTest
@testable import CoverwallShared

final class PlaceholderTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(Coverwall.version, "0.1.0")
    }
}
