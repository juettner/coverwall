using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using CoverwallCore;

namespace CoverwallSaver;

/// <summary>
/// Full-screen mosaic of album covers, mirroring the macOS saver: square
/// tiles edge to edge, no duplicates unless cells outnumber albums, one
/// tile crossfading every few seconds to art that isn't already on screen.
/// Exits on any meaningful input, as Windows screensavers must.
/// </summary>
internal sealed class SaverWindow : Window
{
    private const double FlipIntervalSeconds = 4.0;
    private const double FadeSeconds = 0.4;

    private readonly Canvas _canvas = new() { Background = Brushes.Black };
    private readonly Dictionary<string, BitmapImage> _images = [];
    private readonly List<Image> _tiles = [];
    private readonly List<string> _tileAlbumIds = [];
    private readonly Random _random = new();
    private Point? _firstMouse;

    public SaverWindow()
    {
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        Topmost = true;
        Cursor = Cursors.None;
        Background = Brushes.Black;
        Left = SystemParameters.VirtualScreenLeft;
        Top = SystemParameters.VirtualScreenTop;
        Width = SystemParameters.VirtualScreenWidth;
        Height = SystemParameters.VirtualScreenHeight;
        Content = _canvas;

        KeyDown += (_, _) => Close();
        MouseDown += (_, _) => Close();
        MouseMove += OnMouseMove;

        Loaded += (_, _) =>
        {
            BuildGrid();
            var timer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(FlipIntervalSeconds),
            };
            timer.Tick += (_, _) => FlipRandomTile();
            timer.Start();
        };
    }

    private void OnMouseMove(object sender, MouseEventArgs e)
    {
        var position = e.GetPosition(this);
        _firstMouse ??= position;
        if ((position - _firstMouse.Value).Length > 10) Close();
    }

    private void BuildGrid()
    {
        foreach (var album in new ManifestStore(Paths.ManifestFile).Read())
        {
            var file = Path.Combine(Paths.ImagesDirectory, album.ImageFile);
            if (!File.Exists(file) || _images.ContainsKey(album.AlbumId)) continue;
            try
            {
                var bitmap = new BitmapImage();
                bitmap.BeginInit();
                bitmap.UriSource = new Uri(file);
                bitmap.CacheOption = BitmapCacheOption.OnLoad;
                bitmap.EndInit();
                bitmap.Freeze();
                _images[album.AlbumId] = bitmap;
            }
            catch (Exception ex) when (ex is IOException or NotSupportedException)
            {
                // Skip unreadable images; the wall must never crash.
            }
        }

        var (columns, rows) = MosaicMath.Dimensions(Width, Height);
        var side = Width / columns;

        if (_images.Count == 0)
        {
            ShowPlaceholder(columns, rows, side);
            return;
        }

        var shuffled = _images.Keys.OrderBy(_ => _random.Next()).ToList();
        var assigned = MosaicMath.Assignments(shuffled, columns * rows);
        for (var row = 0; row < rows; row++)
        {
            for (var col = 0; col < columns; col++)
            {
                var albumId = assigned[row * columns + col];
                var tile = new Image
                {
                    Source = _images[albumId],
                    Width = side,
                    Height = side,
                    Stretch = Stretch.UniformToFill,
                };
                Canvas.SetLeft(tile, col * side);
                Canvas.SetTop(tile, row * side);
                _canvas.Children.Add(tile);
                _tiles.Add(tile);
                _tileAlbumIds.Add(albumId);
            }
        }
    }

    private void ShowPlaceholder(int columns, int rows, double side)
    {
        var colors = new[]
        {
            Color.FromRgb(0x2e, 0x3a, 0x4d), Color.FromRgb(0x3d, 0x2e, 0x4d),
            Color.FromRgb(0x4d, 0x3a, 0x2e), Color.FromRgb(0x2e, 0x4d, 0x3a),
        };
        for (var row = 0; row < rows; row++)
        {
            for (var col = 0; col < columns; col++)
            {
                var rect = new System.Windows.Shapes.Rectangle
                {
                    Width = side,
                    Height = side,
                    Fill = new SolidColorBrush(colors[(row + col) % colors.Length]),
                };
                Canvas.SetLeft(rect, col * side);
                Canvas.SetTop(rect, row * side);
                _canvas.Children.Add(rect);
            }
        }
        var message = new TextBlock
        {
            Text = "Play music in Spotify with the Coverwall tray app running —\n" +
                   "your wall builds itself from what you listen to.",
            Foreground = Brushes.White,
            FontSize = 26,
            TextAlignment = TextAlignment.Center,
            Width = Width,
        };
        Canvas.SetTop(message, Height / 2 - 30);
        _canvas.Children.Add(message);
    }

    private void FlipRandomTile()
    {
        if (_tiles.Count == 0 || _images.Count < 2) return;
        switch (MosaicMath.NextFlip(_images.Keys.ToHashSet(), _tileAlbumIds))
        {
            case MosaicMath.FlipMove.Flip(var candidates):
                var index = _random.Next(_tiles.Count);
                var newId = candidates[_random.Next(candidates.Count)];
                Crossfade(index, newId);
                break;
            case MosaicMath.FlipMove.SwapTiles:
                for (var attempt = 0; attempt < 8; attempt++)
                {
                    int i = _random.Next(_tiles.Count), j = _random.Next(_tiles.Count);
                    if (i == j || _tileAlbumIds[i] == _tileAlbumIds[j]) continue;
                    var (a, b) = (_tileAlbumIds[i], _tileAlbumIds[j]);
                    Crossfade(i, b);
                    Crossfade(j, a);
                    break;
                }
                break;
        }
    }

    private void Crossfade(int index, string albumId)
    {
        var tile = _tiles[index];
        _tileAlbumIds[index] = albumId;
        var fadeOut = new DoubleAnimation(1, 0, TimeSpan.FromSeconds(FadeSeconds / 2));
        fadeOut.Completed += (_, _) =>
        {
            tile.Source = _images[albumId];
            tile.BeginAnimation(OpacityProperty,
                new DoubleAnimation(0, 1, TimeSpan.FromSeconds(FadeSeconds / 2)));
        };
        tile.BeginAnimation(OpacityProperty, fadeOut);
    }
}
