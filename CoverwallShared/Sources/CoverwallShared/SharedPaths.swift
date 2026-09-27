import Foundation

public enum SharedPaths {
    public static let appGroupID = "group.com.chadjuettner.coverwall"

    /// Shared data lives in the real-home `~/Library/Application Support/
    /// Coverwall`. History of this decision, all verified empirically:
    /// the App Group container is unreadable from the sandboxed
    /// legacyScreenSaver host (entitlements come from the host, not the
    /// .saver bundle); the host's own container (the Aerial pattern) worked
    /// until macOS 25.6 started gating third-party WRITES into other apps'
    /// containers behind a consent prompt a menu-bar app can never display —
    /// writes hang forever in open(). Real-home Application Support is the
    /// spot both sides can touch: the unsandboxed helper owns it outright,
    /// and the sandboxed saver is allowed to READ it (probed from inside
    /// legacyScreenSaver). The saver must resolve it via the real home from
    /// getpwuid — inside the sandbox, NSHomeDirectory points at the
    /// container instead.
    public static var containerURL: URL {
        let base = realHomeDirectory
            .appendingPathComponent("Library/Application Support/Coverwall",
                                    isDirectory: true)
        try? FileManager.default.createDirectory(at: base,
                                                 withIntermediateDirectories: true)
        return base
    }

    private static var realHomeDirectory: URL {
        if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
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
