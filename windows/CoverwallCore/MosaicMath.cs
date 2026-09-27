namespace CoverwallCore;

/// <summary>
/// Pure mosaic decisions, ported from the macOS MosaicGrid/MosaicAssignment:
/// square tiles edge to edge, no duplicate albums unless cells outnumber
/// albums, and flips that never introduce a duplicate.
/// </summary>
public static class MosaicMath
{
    public const double TileWidth = 200;

    public static (int Columns, int Rows) Dimensions(double width, double height,
                                                     double tileWidth = TileWidth)
    {
        if (width <= 0 || height <= 0) return (1, 1);
        var columns = Math.Max(1, (int)Math.Round(width / tileWidth));
        var tileSide = width / columns;
        var rows = Math.Max(1, (int)Math.Ceiling(height / tileSide));
        return (columns, rows);
    }

    /// <summary>
    /// Album for each cell, in cell order. No album repeats until every
    /// album has been used once; wraps only when cells outnumber albums.
    /// </summary>
    public static List<string> Assignments(IReadOnlyList<string> albumIds, int cellCount)
    {
        if (albumIds.Count == 0 || cellCount <= 0) return [];
        return Enumerable.Range(0, cellCount)
            .Select(i => albumIds[i % albumIds.Count])
            .ToList();
    }

    public abstract record FlipMove
    {
        public sealed record Flip(IReadOnlyList<string> Candidates) : FlipMove;
        public sealed record SwapTiles : FlipMove;
        public sealed record None : FlipMove;
    }

    /// <summary>
    /// Prefers albums not currently displayed so flips never introduce a
    /// duplicate; swaps two tiles when everything is on screen.
    /// </summary>
    public static FlipMove NextFlip(IReadOnlySet<string> allAlbums,
                                    IReadOnlyList<string> displayed)
    {
        if (allAlbums.Count < 2) return new FlipMove.None();
        var offscreen = allAlbums.Except(displayed).OrderBy(x => x).ToList();
        return offscreen.Count == 0
            ? new FlipMove.SwapTiles()
            : new FlipMove.Flip(offscreen);
    }
}
