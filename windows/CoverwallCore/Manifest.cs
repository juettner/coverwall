using System.Text.Json;

namespace CoverwallCore;

/// <summary>One album the screensaver should display.</summary>
public sealed record AlbumEntry(
    string AlbumId,
    string Title,
    string Artist,
    string ImageFile,
    DateTimeOffset AddedAt);

/// <summary>
/// The tray-app → screensaver contract: which covers to show, newest
/// first. Written atomically so the saver never sees a half-written state.
/// </summary>
public sealed class ManifestStore(string path)
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
    };

    public void Write(IReadOnlyList<AlbumEntry> albums)
    {
        var tmp = path + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(albums, Options));
        File.Move(tmp, path, overwrite: true);
    }

    public List<AlbumEntry> Read()
    {
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<List<AlbumEntry>>(stream, Options) ?? [];
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            return [];
        }
    }

    public DateTimeOffset? LastModified()
    {
        try
        {
            return File.GetLastWriteTimeUtc(path);
        }
        catch (IOException)
        {
            return null;
        }
    }
}

/// <summary>
/// Builds the manifest from observed plays: newest first, deduped by album,
/// limited to albums whose cover image actually exists on disk.
/// </summary>
public static class ManifestBuilder
{
    public const int MaxAlbums = 60;

    public static List<AlbumEntry> Build(
        IEnumerable<LocalPlay> playsNewestFirst,
        Func<string, string?> imageFileForAlbumId)
    {
        var seen = new HashSet<string>();
        var albums = new List<AlbumEntry>();
        foreach (var play in playsNewestFirst)
        {
            if (!seen.Add(play.AlbumKey)) continue;
            var albumId = Paths.StableAlbumId(play.AlbumKey);
            var imageFile = imageFileForAlbumId(albumId);
            if (imageFile is null) continue;
            albums.Add(new AlbumEntry(albumId, play.Album, play.Artist,
                                      imageFile, play.PlayedAt));
            if (albums.Count >= MaxAlbums) break;
        }
        return albums;
    }
}
