import Foundation

public enum SharedPaths {
    public static let appGroupID = "group.com.chadjuettner.coverwall"

    /// The shared data directory must be readable by the saver, which runs
    /// inside Apple's sandboxed legacyScreenSaver host. That sandbox does NOT
    /// carry our app-group entitlement (entitlements come from the host, not
    /// the .saver bundle), so the App Group container is unreadable there —
    /// verified empirically: reads fail with EPERM. The one location both
    /// sides can touch is the host's own container: the sandboxed saver
    /// resolves its Application Support inside it, and the unsandboxed helper
    /// writes into the container path directly (the Aerial pattern).
    private static let saverHostContainerSuffix =
        "com.apple.ScreenSaver.Engine.legacyScreenSaver"

    public static var containerURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
        let base: URL
        if appSupport.path.contains(saverHostContainerSuffix) {
            // Sandboxed saver: its own Application Support IS the shared spot.
            base = appSupport.appendingPathComponent("Coverwall", isDirectory: true)
        } else {
            // Helper, preview app, tests (unsandboxed): reach into the host's
            // container explicitly.
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/\(saverHostContainerSuffix)/Data/Library/Application Support/Coverwall",
                                        isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: base,
                                                 withIntermediateDirectories: true)
        return base
    }

    public static var imagesDirectory: URL {
        let url = containerURL.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url,
                                                 withIntermediateDirectories: true)
        return url
    }

    public static var manifestURL: URL {
        containerURL.appendingPathComponent("manifest.json")
    }
}
