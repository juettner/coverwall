using System.Security.Cryptography;
using System.Text;

namespace CoverwallCore;

/// <summary>
/// Shared data locations and identities. The tray app owns the data
/// directory; the screensaver only reads it.
/// </summary>
public static class Paths
{
    public static string DataDirectory
    {
        get
        {
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Coverwall");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }

    public static string ImagesDirectory
    {
        get
        {
            var dir = Path.Combine(DataDirectory, "images");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }

    public static string PlaysFile => Path.Combine(DataDirectory, "local-plays.json");
    public static string ManifestFile => Path.Combine(DataDirectory, "manifest.json");

    public static string AlbumKey(string artist, string album) =>
        $"{artist}|{album}".ToLowerInvariant();

    /// <summary>
    /// Deterministic, filename-safe album ID (matches the macOS approach:
    /// a truncated SHA-256 of the album key).
    /// </summary>
    public static string StableAlbumId(string albumKey)
    {
        var hex = Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(albumKey))).ToLowerInvariant();
        return "local-" + hex[..16];
    }
}
