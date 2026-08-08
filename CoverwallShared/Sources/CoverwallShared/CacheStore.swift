import Foundation

public struct CacheStore {
    private let directory: URL

    public init(directory: URL = SharedPaths.imagesDirectory) {
        self.directory = directory
    }

    public func filename(forAlbumID id: String) -> String { "\(id).jpg" }

    public func imageURL(filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    public func contains(albumID: String) -> Bool {
        FileManager.default.fileExists(atPath: imageURL(filename: filename(forAlbumID: albumID)).path)
    }

    public func store(_ data: Data, albumID: String) throws {
        try data.write(to: imageURL(filename: filename(forAlbumID: albumID)), options: .atomic)
    }

    public func prune(keeping albumIDs: [String], cap: Int = 200) {
        let fm = FileManager.default
        let keep = Set(albumIDs.map(filename(forAlbumID:)))
        guard let files = try? fm.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey]) else { return }

        var kept: [(url: URL, modified: Date)] = []
        for file in files {
            if keep.contains(file.lastPathComponent) {
                let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                kept.append((file, date))
            } else {
                try? fm.removeItem(at: file)
            }
        }
        if kept.count > cap {
            for extra in kept.sorted(by: { $0.modified < $1.modified }).prefix(kept.count - cap) {
                try? fm.removeItem(at: extra.url)
            }
        }
    }
}
