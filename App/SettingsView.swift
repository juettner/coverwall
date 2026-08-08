import SwiftUI
import CoverwallShared

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var artSource: ArtSource = .recentlyPlayed
    @State private var range: TopTracksRange = .mediumTerm
    @State private var density: TileDensity = .medium
    @State private var flipInterval = 4.0
    @State private var showLabels = false

    var body: some View {
        Form {
            Picker("Art source", selection: $artSource) {
                Text("Recently played").tag(ArtSource.recentlyPlayed)
                Text("Top tracks").tag(ArtSource.topTracks)
                Text("Liked Songs").tag(ArtSource.likedSongs)
            }
            if artSource == .topTracks {
                Picker("Time range", selection: $range) {
                    Text("Last 4 weeks").tag(TopTracksRange.shortTerm)
                    Text("Last 6 months").tag(TopTracksRange.mediumTerm)
                    Text("All time").tag(TopTracksRange.longTerm)
                }
            }
            Picker("Tile size", selection: $density) {
                Text("Small").tag(TileDensity.small)
                Text("Medium").tag(TileDensity.medium)
                Text("Large").tag(TileDensity.large)
            }
            Slider(value: $flipInterval, in: 2...15, step: 0.5) {
                Text("Flip every \(flipInterval, specifier: "%.1f")s")
            }
            Toggle("Show artist/title on flip", isOn: $showLabels)
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            artSource = model.settings.artSource
            range = model.settings.topTracksRange
            density = model.settings.tileDensity
            flipInterval = model.settings.flipInterval
            showLabels = model.settings.showLabels
        }
        .onChange(of: artSource) { _, v in
            model.settings.artSource = v
            model.restartScheduler()
            Task { await model.refreshNow() }
        }
        .onChange(of: range) { _, v in
            model.settings.topTracksRange = v
            Task { await model.refreshNow() }
        }
        .onChange(of: density) { _, v in model.settings.tileDensity = v }
        .onChange(of: flipInterval) { _, v in model.settings.flipInterval = v }
        .onChange(of: showLabels) { _, v in model.settings.showLabels = v }
    }
}
