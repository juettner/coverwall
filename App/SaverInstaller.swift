import Foundation
import CoverwallShared

enum SaverInstaller {
    static func installIfNeeded() {
        guard let bundled = Bundle.main.url(forResource: "Coverwall", withExtension: "saver") else {
            return
        }
        let fm = FileManager.default
        let dest = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers/Coverwall.saver")

        let bundledVersion = version(of: bundled)
        let installedVersion = version(of: dest)
        guard bundledVersion != installedVersion else { return }

        try? fm.removeItem(at: dest)
        try? fm.createDirectory(at: dest.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        try? fm.copyItem(at: bundled, to: dest)
    }

    private static func version(of bundleURL: URL) -> String? {
        Bundle(url: bundleURL)?
            .object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}
