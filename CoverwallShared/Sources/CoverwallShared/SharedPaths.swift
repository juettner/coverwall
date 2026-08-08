import Foundation

public enum SharedPaths {
    public static let appGroupID = "group.com.chadjuettner.coverwall"

    public static var containerURL: URL {
        let base: URL
        if let group = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            base = group
        } else {
            base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
                .appendingPathComponent("Coverwall", isDirectory: true)
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
