import Foundation

/// Pure decisions about which album goes where, kept out of MosaicView so
/// they can be unit tested. The grid should never show the same album twice
/// unless there are more cells than albums.
public enum MosaicAssignment {
    /// Album for each cell, in cell order. No album repeats until every album
    /// has been used once; wraps around only when cells outnumber albums.
    public static func assignments(albumIDs: [String], cellCount: Int) -> [String] {
        guard !albumIDs.isEmpty, cellCount > 0 else { return [] }
        return (0..<cellCount).map { albumIDs[$0 % albumIDs.count] }
    }

    public enum FlipMove: Equatable {
        /// Flip one tile to one of these albums (none of them currently shown).
        case flip(candidates: [String])
        /// Every album is already on screen — swap two tiles instead.
        case swapTiles
        /// Fewer than two albums; nothing sensible to animate.
        case none
    }

    /// Prefers albums not currently displayed so flips never introduce a
    /// duplicate; falls back to swapping tiles when everything is on screen.
    public static func flipMove(allAlbums: Set<String>, displayed: [String]) -> FlipMove {
        guard allAlbums.count >= 2 else { return .none }
        let offscreen = allAlbums.subtracting(displayed).sorted()
        return offscreen.isEmpty ? .swapTiles : .flip(candidates: offscreen)
    }
}
