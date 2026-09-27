using System.Text.Json;

namespace CoverwallCore;

/// <summary>
/// Persists observed plays as JSON (newest first), consecutive-deduped and
/// capped — the C# twin of the macOS LocalPlaysStore. Single writer (the
/// tray app).
/// </summary>
public sealed class PlaysStore(string path)
{
    public const int Cap = 300;

    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
    };

    public void Record(LocalPlay play)
    {
        var plays = RecentPlays();
        if (plays.Count > 0 && SameTrack(plays[0], play))
        {
            plays[0] = play;  // same track re-reported (seek/pause): refresh timestamp
        }
        else
        {
            plays.Insert(0, play);
        }
        Write(plays.Take(Cap).ToList());
    }

    public List<LocalPlay> RecentPlays()
    {
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<List<LocalPlay>>(stream, Options) ?? [];
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            return [];
        }
    }

    public int DistinctAlbumCount() =>
        RecentPlays().Select(p => p.AlbumKey).Distinct().Count();

    private static bool SameTrack(LocalPlay a, LocalPlay b) =>
        a.Title == b.Title && a.Artist == b.Artist && a.Album == b.Album;

    private void Write(List<LocalPlay> plays)
    {
        var tmp = path + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(plays, Options));
        File.Move(tmp, path, overwrite: true);
    }
}
