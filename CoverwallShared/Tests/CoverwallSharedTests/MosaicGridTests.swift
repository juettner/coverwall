import XCTest
@testable import CoverwallShared

final class MosaicGridTests: XCTestCase {
    func testMediumDensityOn16x10() {
        let d = MosaicGrid.dimensions(for: CGSize(width: 1600, height: 1000), density: .medium)
        XCTAssertEqual(d.columns, 8)
        XCTAssertEqual(d.rows, 5)
    }

    func testTinySizeNeverZero() {
        let d = MosaicGrid.dimensions(for: CGSize(width: 10, height: 10), density: .large)
        XCTAssertGreaterThanOrEqual(d.columns, 1)
        XCTAssertGreaterThanOrEqual(d.rows, 1)
    }

    func testLargeTilesMeansFewerColumns() {
        let small = MosaicGrid.dimensions(for: CGSize(width: 1600, height: 1000), density: .small).columns
        let large = MosaicGrid.dimensions(for: CGSize(width: 1600, height: 1000), density: .large).columns
        XCTAssertGreaterThan(small, large)
    }
}
