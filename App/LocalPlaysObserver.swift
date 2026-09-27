import Foundation
import CoverwallShared

/// Records what the Spotify desktop app plays on this Mac, via the
/// distributed notification it broadcasts on every playback change.
/// No API, no login, no permissions — works for users outside the
/// Spotify app's allowlist.
///
/// Uses the selector-based observer API because it is the only one that
/// accepts a suspension behavior: macOS suspends distributed-notification
/// delivery to apps that aren't active, and an LSUIElement menu-bar app
/// never is — without `.deliverImmediately`, nothing ever arrives.
final class LocalPlaysObserver: NSObject {
    private let store = LocalPlaysStore()
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(playbackChanged(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            suspensionBehavior: .deliverImmediately)
    }

    @objc private func playbackChanged(_ note: Notification) {
        guard let info = note.userInfo,
              let play = LocalPlay.from(notificationUserInfo: info) else { return }
        store.record(play)
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
