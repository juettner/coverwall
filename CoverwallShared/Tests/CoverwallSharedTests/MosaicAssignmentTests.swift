import XCTest
@testable import CoverwallShared

final class MosaicAssignmentTests: XCTestCase {
    func testNoDuplicatesWhenEnoughAlbums() {
        let ids = (0..<10).map { "a\($0)" }
        let assigned = MosaicAssignment.assignments(albumIDs: ids, cellCount: 8)
        XCTAssertEqual(assigned.count, 8)
        XCTAssertEqual(Set(assigned).count, 8)
    }

    func testWrapsEvenlyWhenFewerAlbumsThanCells() {
        let assigned = MosaicAssignment.assignments(albumIDs: ["a", "b", "c"], cellCount: 7)
        XCTAssertEqual(assigned.count, 7)
        XCTAssertEqual(Set(assigned), ["a", "b", "c"])
        let counts = Dictionary(grouping: assigned, by: { $0 }).mapValues(\.count)
        XCTAssertLessThanOrEqual(counts.values.max()! - counts.values.min()!, 1)
    }

    func testEmptyInputs() {
        XCTAssertTrue(MosaicAssignment.assignments(albumIDs: [], cellCount: 5).isEmpty)
        XCTAssertTrue(MosaicAssignment.assignments(albumIDs: ["a"], cellCount: 0).isEmpty)
    }

    func testFlipPrefersOffscreenAlbums() {
        let move = MosaicAssignment.flipMove(allAlbums: ["a", "b", "c", "d"],
                                            displayed: ["a", "b"])
        XCTAssertEqual(move, .flip(candidates: ["c", "d"]))
    }

    func testFlipSwapsWhenEverythingIsDisplayed() {
        let move = MosaicAssignment.flipMove(allAlbums: ["a", "b"],
                                            displayed: ["a", "b", "a"])
        XCTAssertEqual(move, .swapTiles)
    }

    func testFlipNoneWithFewerThanTwoAlbums() {
        XCTAssertEqual(MosaicAssignment.flipMove(allAlbums: ["a"], displayed: ["a"]), .none)
        XCTAssertEqual(MosaicAssignment.flipMove(allAlbums: [], displayed: []), .none)
    }
}
