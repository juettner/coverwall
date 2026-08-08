import AppKit
import CoverwallShared

final class RefreshScheduler {
    private let settings: SharedSettings
    private let onFire: () async -> Void
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init(settings: SharedSettings, onFire: @escaping () async -> Void) {
        self.settings = settings
        self.onFire = onFire
    }

    var interval: TimeInterval {
        settings.artSource == .recentlyPlayed ? 15 * 60 : 60 * 60
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.onFire() }
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.onFire() }
        }
    }

    deinit {
        timer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}
