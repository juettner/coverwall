import SwiftUI
import CoverwallShared

@main
struct CoverwallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra("Coverwall", systemImage: "square.grid.3x3.fill") {
            Text(model.statusLine)
            Divider()
            Button("Refresh Now") { Task { await model.refreshNow() } }
                .disabled(!model.isConnected)
            SettingsMenuButton()
            if model.isConnected {
                Button("Disconnect Spotify") { model.disconnect() }
            } else {
                Button("Connect Spotify…") { Task { await model.connect() } }
            }
            Divider()
            Button("Quit Coverwall") { NSApplication.shared.terminate(nil) }
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

// SettingsLink alone doesn't activate an LSUIElement app, so the Settings
// window opens behind every other window with no Dock/Cmd-Tab way to find it.
private struct SettingsMenuButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openSettings()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        SaverInstaller.installIfNeeded()
        AppModel.shared.startScheduler()
        AppModel.shared.registerLoginItem()
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var statusLine = "Not connected"
    @Published var isConnected = false

    let settings = SharedSettings()
    private let tokenStore = TokenStore()
    private let auth = AuthController()
    private var scheduler: RefreshScheduler?
    private var isRefreshing = false

    private var coordinator: FetchCoordinator {
        FetchCoordinator(client: SpotifyClient(), tokens: tokenStore,
                         cache: CacheStore(), manifests: ManifestStore(),
                         settings: settings)
    }

    private init() {
        isConnected = tokenStore.load() != nil
        statusLine = isConnected ? "Connected" : "Not connected"
    }

    func startScheduler() {
        scheduler = RefreshScheduler(settings: settings) { [weak self] in
            await self?.refreshNow()
        }
        scheduler?.start()
        Task { await refreshNow() }
    }

    func registerLoginItem() {
        try? SMAppServiceShim.registerLoginItem()
    }

    func restartScheduler() {
        scheduler?.start()
    }

    func connect() async {
        do {
            let tokens = try await auth.authorize()
            try tokenStore.save(tokens)
            isConnected = true
            await refreshNow()
        } catch {
            statusLine = "Login failed — try again"
        }
    }

    func disconnect() {
        tokenStore.delete()
        isConnected = false
        statusLine = "Not connected"
    }

    func refreshNow() async {
        guard isRefreshing == false else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        statusLine = "Refreshing…"
        switch await coordinator.refresh() {
        case .updated(let count):
            statusLine = "\(count) albums · updated \(Date().formatted(date: .omitted, time: .shortened))"
        case .starter(let count):
            statusLine = "\(count) covers from the global charts — connect Spotify to make it yours"
        case .notLoggedIn:
            isConnected = false
            statusLine = "Not connected"
        case .failed:
            statusLine = isConnected ? "Refresh failed — will retry" : "Not connected"
        }
    }
}
