using System.Windows;

namespace CoverwallSaver;

/// <summary>
/// A Windows screensaver is just an executable renamed to .scr that honors
/// three flags: /s show, /c configure, /p preview-in-dialog.
/// </summary>
internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        var mode = args.FirstOrDefault()?.ToLowerInvariant().Split(':')[0] ?? "/s";
        switch (mode)
        {
            case "/c":
                MessageBox.Show(
                    "Coverwall shows a wall of album art from what you play in Spotify.\n\n" +
                    "Run CoverwallTray.exe (keep it in your startup apps) so plays are " +
                    "collected — the wall personalizes itself as you listen.",
                    "Coverwall", MessageBoxButton.OK, MessageBoxImage.Information);
                break;
            case "/p":
                break;  // no miniature preview
            default:
                var app = new Application
                {
                    ShutdownMode = ShutdownMode.OnMainWindowClose,
                };
                app.Run(new SaverWindow());
                break;
        }
    }
}
