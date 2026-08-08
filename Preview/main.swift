import AppKit
import CoverwallShared

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var mosaic: MosaicView!
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SharedSettings()
        mosaic = MosaicView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
        mosaic.flipInterval = settings.flipInterval
        mosaic.showLabels = settings.showLabels
        mosaic.configure(density: settings.tileDensity)

        if let manifest = ManifestStore().read() {
            mosaic.setAlbums(manifest.albums, cache: CacheStore())
        }

        window = NSWindow(contentRect: mosaic.frame,
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Coverwall Preview"
        window.contentView = mosaic
        window.makeKeyAndOrderFront(nil)

        timer = Timer.scheduledTimer(withTimeInterval: mosaic.flipInterval,
                                     repeats: true) { [weak self] _ in
            self?.mosaic.flipRandomTile()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
