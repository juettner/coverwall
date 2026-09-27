namespace CoverwallCore;

/// <summary>
/// One observed play from the Spotify desktop app, captured via Windows'
/// System Media Transport Controls — no API, no login.
/// </summary>
public sealed record LocalPlay(
    string Title,
    string Artist,
    string Album,
    DateTimeOffset PlayedAt)
{
    /// <summary>Case-insensitive identity of the album this play belongs to.</summary>
    public string AlbumKey => Paths.AlbumKey(Artist, Album);
}
