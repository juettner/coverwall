using CoverwallCore;
using Xunit;

namespace CoverwallCore.Tests;

public class PlaysStoreTests : IDisposable
{
    private readonly string _path = Path.Combine(
        Path.GetTempPath(), $"plays-{Guid.NewGuid():N}.json");

    private PlaysStore Store => new(_path);

    private static LocalPlay Play(string title, string album = "A", long t = 0) =>
        new(title, "Artist", album, DateTimeOffset.FromUnixTimeSeconds(t));

    [Fact]
    public void RecordsAndPersistsNewestFirst()
    {
        Store.Record(Play("t1", t: 100));
        Store.Record(Play("t2", album: "B", t: 200));
        var plays = new PlaysStore(_path).RecentPlays();
        Assert.Equal(["t2", "t1"], plays.Select(p => p.Title));
    }

    [Fact]
    public void ConsecutiveSameTrackUpdatesInsteadOfAppending()
    {
        Store.Record(Play("t1", t: 100));
        Store.Record(Play("t1", t: 250));
        var plays = Store.RecentPlays();
        Assert.Single(plays);
        Assert.Equal(250, plays[0].PlayedAt.ToUnixTimeSeconds());
    }

    [Fact]
    public void CapDropsOldest()
    {
        for (var i = 0; i < 310; i++) Store.Record(Play($"t{i}", t: i));
        var plays = Store.RecentPlays();
        Assert.Equal(PlaysStore.Cap, plays.Count);
        Assert.Equal("t309", plays[0].Title);
        Assert.DoesNotContain(plays, p => p.Title == "t0");
    }

    [Fact]
    public void DistinctAlbumCountIsCaseInsensitive()
    {
        Store.Record(Play("t1", album: "Blue", t: 1));
        Store.Record(Play("t2", album: "Gold", t: 2));
        Store.Record(Play("t3", album: "blue", t: 3));
        Assert.Equal(2, Store.DistinctAlbumCount());
    }

    [Fact]
    public void MissingOrCorruptFileReadsEmpty()
    {
        Assert.Empty(Store.RecentPlays());
        File.WriteAllText(_path, "not json");
        Assert.Empty(Store.RecentPlays());
    }

    public void Dispose() => File.Delete(_path);
}

public class ManifestTests : IDisposable
{
    private readonly string _path = Path.Combine(
        Path.GetTempPath(), $"manifest-{Guid.NewGuid():N}.json");

    [Fact]
    public void RoundTrips()
    {
        var store = new ManifestStore(_path);
        var albums = new List<AlbumEntry>
        {
            new("local-abc", "Blue", "Joni Mitchell", "local-abc.jpg",
                DateTimeOffset.FromUnixTimeSeconds(900)),
        };
        store.Write(albums);
        Assert.Equal(albums, new ManifestStore(_path).Read());
    }

    [Fact]
    public void BuilderDedupesByAlbumAndSkipsMissingImages()
    {
        var plays = new List<LocalPlay>
        {
            new("t3", "A2", "Album Two", DateTimeOffset.FromUnixTimeSeconds(300)),
            new("t2", "A1", "Album One", DateTimeOffset.FromUnixTimeSeconds(200)),
            new("t1", "A1", "Album One", DateTimeOffset.FromUnixTimeSeconds(100)),
            new("t0", "A0", "No Image", DateTimeOffset.FromUnixTimeSeconds(50)),
        };
        var noImage = Paths.StableAlbumId(Paths.AlbumKey("A0", "No Image"));
        var manifest = ManifestBuilder.Build(plays,
            id => id == noImage ? null : id + ".jpg");
        Assert.Equal(2, manifest.Count);
        Assert.Equal("Album Two", manifest[0].Title);
        Assert.Equal("Album One", manifest[1].Title);
    }

    public void Dispose() => File.Delete(_path);
}

public class MosaicMathTests
{
    [Fact]
    public void DimensionsMatchMacBehavior()
    {
        Assert.Equal((8, 5), MosaicMath.Dimensions(1600, 1000));
        Assert.Equal((1, 1), MosaicMath.Dimensions(10, 10, tileWidth: 320));
    }

    [Fact]
    public void AssignmentsHaveNoDuplicatesWhenEnoughAlbums()
    {
        var ids = Enumerable.Range(0, 10).Select(i => $"a{i}").ToList();
        var assigned = MosaicMath.Assignments(ids, 8);
        Assert.Equal(8, assigned.Count);
        Assert.Equal(8, assigned.Distinct().Count());
    }

    [Fact]
    public void FlipPrefersOffscreenThenSwaps()
    {
        var flip = MosaicMath.NextFlip(
            new HashSet<string> { "a", "b", "c" }, ["a", "b"]);
        var candidates = Assert.IsType<MosaicMath.FlipMove.Flip>(flip).Candidates;
        Assert.Equal(["c"], candidates);

        Assert.IsType<MosaicMath.FlipMove.SwapTiles>(
            MosaicMath.NextFlip(new HashSet<string> { "a", "b" }, ["a", "b"]));
        Assert.IsType<MosaicMath.FlipMove.None>(
            MosaicMath.NextFlip(new HashSet<string> { "a" }, ["a"]));
    }

    [Fact]
    public void StableAlbumIdIsDeterministicAndFilenameSafe()
    {
        var id = Paths.StableAlbumId("artist|album");
        Assert.Equal(id, Paths.StableAlbumId("artist|album"));
        Assert.StartsWith("local-", id);
        Assert.Equal(22, id.Length);
        Assert.DoesNotContain(Path.GetInvalidFileNameChars(), c => id.Contains(c));
    }
}
