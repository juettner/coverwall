using CoverwallCore;
using Windows.Media.Control;

namespace CoverwallTray;

/// <summary>
/// Tray app: watches Windows' System Media Transport Controls for Spotify
/// playback and builds the Coverwall data (plays, cover images, manifest)
/// that the screensaver renders. No Spotify API, no login — SMTC even
/// hands over the album art bytes locally.
/// </summary>
internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new TrayContext());
    }
}

internal sealed class TrayContext : ApplicationContext
{
    private readonly NotifyIcon _icon;
    private readonly SpotifyWatcher _watcher = new();

    public TrayContext()
    {
        var menu = new ContextMenuStrip();
        var status = new ToolStripMenuItem("Coverwall — watching Spotify") { Enabled = false };
        menu.Items.Add(status);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Exit", null, (_, _) => ExitThread());

        _icon = new NotifyIcon
        {
            Icon = System.Drawing.SystemIcons.Application,
            Text = "Coverwall",
            Visible = true,
            ContextMenuStrip = menu,
        };

        _watcher.StatusChanged += text => status.Text = text;
        _ = _watcher.StartAsync();
    }

    protected override void ExitThreadCore()
    {
        _icon.Visible = false;
        _icon.Dispose();
        base.ExitThreadCore();
    }
}

internal sealed class SpotifyWatcher
{
    private readonly PlaysStore _plays = new(Paths.PlaysFile);
    private readonly ManifestStore _manifest = new(Paths.ManifestFile);
    private GlobalSystemMediaTransportControlsSessionManager? _manager;
    private GlobalSystemMediaTransportControlsSession? _session;

    public event Action<string>? StatusChanged;

    public async Task StartAsync()
    {
        try
        {
            _manager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
            _manager.SessionsChanged += (_, _) => BindSpotifySession();
            BindSpotifySession();
        }
        catch (Exception ex)
        {
            StatusChanged?.Invoke($"Media watcher failed: {ex.Message}");
        }
    }

    private void BindSpotifySession()
    {
        if (_manager is null) return;
        var spotify = _manager.GetSessions().FirstOrDefault(s =>
            s.SourceAppUserModelId.Contains("spotify", StringComparison.OrdinalIgnoreCase));
        if (ReferenceEquals(spotify, _session)) return;

        if (_session is not null)
        {
            _session.MediaPropertiesChanged -= OnSessionChanged;
            _session.PlaybackInfoChanged -= OnSessionChanged;
        }
        _session = spotify;
        if (_session is null)
        {
            StatusChanged?.Invoke("Coverwall — waiting for Spotify");
            return;
        }
        _session.MediaPropertiesChanged += OnSessionChanged;
        _session.PlaybackInfoChanged += OnSessionChanged;
        StatusChanged?.Invoke("Coverwall — watching Spotify");
        _ = CaptureAsync();
    }

    private void OnSessionChanged(object? sender, object args) => _ = CaptureAsync();

    private async Task CaptureAsync()
    {
        var session = _session;
        if (session is null) return;
        try
        {
            if (session.GetPlaybackInfo().PlaybackStatus !=
                GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing)
            {
                return;
            }
            var props = await session.TryGetMediaPropertiesAsync();
            if (string.IsNullOrWhiteSpace(props.Title) ||
                string.IsNullOrWhiteSpace(props.Artist))
            {
                return;  // ads and transient states
            }
            var album = string.IsNullOrWhiteSpace(props.AlbumTitle)
                ? props.Title  // singles sometimes report no album
                : props.AlbumTitle;
            var play = new LocalPlay(props.Title, props.Artist, album,
                                     DateTimeOffset.UtcNow);
            _plays.Record(play);
            await SaveThumbnailAsync(props, play);
            RebuildManifest();
        }
        catch (Exception ex)
        {
            StatusChanged?.Invoke($"Coverwall — hiccup: {ex.Message}");
        }
    }

    private static async Task SaveThumbnailAsync(
        GlobalSystemMediaTransportControlsSessionMediaProperties props, LocalPlay play)
    {
        if (props.Thumbnail is null) return;
        var path = Path.Combine(Paths.ImagesDirectory,
                                Paths.StableAlbumId(play.AlbumKey) + ".jpg");
        if (File.Exists(path)) return;

        using var winrtStream = await props.Thumbnail.OpenReadAsync();
        using var source = winrtStream.AsStreamForRead();
        var tmp = path + ".tmp";
        await using (var dest = File.Create(tmp))
        {
            await source.CopyToAsync(dest);
        }
        File.Move(tmp, path, overwrite: true);
    }

    private void RebuildManifest()
    {
        var albums = ManifestBuilder.Build(_plays.RecentPlays(), albumId =>
        {
            var file = albumId + ".jpg";
            return File.Exists(Path.Combine(Paths.ImagesDirectory, file)) ? file : null;
        });
        _manifest.Write(albums);
    }
}
