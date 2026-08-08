import AppKit

public enum MosaicGrid {
    public static func dimensions(for size: CGSize, density: TileDensity)
        -> (columns: Int, rows: Int) {
        guard size.width > 0, size.height > 0 else { return (1, 1) }
        let columns = max(1, Int((size.width / density.approximateTileWidth).rounded()))
        let tileSide = size.width / CGFloat(columns)
        let rows = max(1, Int(ceil(size.height / tileSide)))
        return (columns, rows)
    }
}

/// Grid view for rendering album art tiles with flip animations and placeholder mode.
/// All methods and properties must be used from the main thread.
public final class MosaicView: NSView {
    public var flipInterval: TimeInterval = 4.0
    public var showLabels = false

    private var density: TileDensity = .medium
    private var albums: [AlbumArt] = []
    private var images: [String: NSImage] = [:]  // albumID → image
    private var tileLayers: [CALayer] = []
    private var tileAlbumIDs: [String] = []
    private let placeholderColors: [NSColor] = [
        NSColor(calibratedHue: 0.58, saturation: 0.25, brightness: 0.30, alpha: 1),
        NSColor(calibratedHue: 0.75, saturation: 0.20, brightness: 0.25, alpha: 1),
        NSColor(calibratedHue: 0.08, saturation: 0.22, brightness: 0.28, alpha: 1),
        NSColor(calibratedHue: 0.35, saturation: 0.18, brightness: 0.24, alpha: 1),
    ]
    private var messageLayer: CATextLayer?
    private var labelLayer: CATextLayer?

    public override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
    }

    public required init?(coder: NSCoder) { fatalError("not used") }

    public func configure(density: TileDensity) {
        self.density = density
        rebuildGrid()
    }

    public func setAlbums(_ albums: [AlbumArt], cache: CacheStore) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var loaded: [String: NSImage] = [:]
            for album in albums {
                if let image = NSImage(contentsOf: cache.imageURL(filename: album.imageFilename)) {
                    loaded[album.albumID] = image
                }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.albums = albums
                self.images = loaded
                self.rebuildGrid()
            }
        }
    }

    public override func layout() {
        super.layout()
        rebuildGrid()
    }

    private var isPlaceholder: Bool { images.isEmpty }

    private func rebuildGrid() {
        guard let hostLayer = layer, bounds.width > 1, bounds.height > 1 else { return }
        tileLayers.forEach { $0.removeFromSuperlayer() }
        messageLayer?.removeFromSuperlayer()
        labelLayer?.removeFromSuperlayer()
        tileLayers = []
        tileAlbumIDs = []
        labelLayer = nil

        let (columns, rows) = MosaicGrid.dimensions(for: bounds.size, density: density)
        let side = bounds.width / CGFloat(columns)
        let ids = images.keys.sorted()

        for row in 0..<rows {
            for col in 0..<columns {
                let tile = CALayer()
                tile.frame = CGRect(x: CGFloat(col) * side,
                                    y: bounds.height - CGFloat(row + 1) * side,
                                    width: side, height: side)
                tile.contentsGravity = .resizeAspectFill
                tile.masksToBounds = true
                tile.contentsScale = window?.backingScaleFactor ?? 2
                if isPlaceholder {
                    tile.backgroundColor = placeholderColors[(row + col) % placeholderColors.count].cgColor
                    tileAlbumIDs.append("")
                } else {
                    let id = ids[(row * columns + col) % ids.count]
                    tile.contents = images[id]
                    tileAlbumIDs.append(id)
                }
                hostLayer.addSublayer(tile)
                tileLayers.append(tile)
            }
        }

        if isPlaceholder {
            let text = CATextLayer()
            text.string = "Open Coverwall to connect your Spotify account"
            text.font = NSFont.systemFont(ofSize: 24, weight: .medium)
            text.fontSize = 24
            text.foregroundColor = NSColor.white.withAlphaComponent(0.85).cgColor
            text.alignmentMode = .center
            text.contentsScale = window?.backingScaleFactor ?? 2
            text.frame = CGRect(x: 0, y: bounds.midY - 20, width: bounds.width, height: 40)
            hostLayer.addSublayer(text)
            messageLayer = text
        }
    }

    public func flipRandomTile() {
        guard !isPlaceholder, images.count > 1, !tileLayers.isEmpty else { return }
        let index = Int.random(in: 0..<tileLayers.count)
        let currentID = tileAlbumIDs[index]
        guard let newID = images.keys.filter({ $0 != currentID }).randomElement(),
              let newImage = images[newID] else { return }

        let tile = tileLayers[index]
        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.8
        tile.add(transition, forKey: "flip")
        tile.contents = newImage
        tileAlbumIDs[index] = newID

        if showLabels, let album = albums.first(where: { $0.albumID == newID }) {
            showLabel("\(album.artist) — \(album.title)")
        }
    }

    private func showLabel(_ text: String) {
        labelLayer?.removeFromSuperlayer()
        let label = CATextLayer()
        label.string = text
        label.fontSize = 16
        label.foregroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
        label.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        label.cornerRadius = 6
        label.alignmentMode = .center
        label.contentsScale = window?.backingScaleFactor ?? 2
        let width = min(bounds.width - 40, CGFloat(text.count) * 10 + 40)
        label.frame = CGRect(x: 20, y: 20, width: width, height: 28)
        layer?.addSublayer(label)
        labelLayer = label
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.labelLayer === label {
                label.removeFromSuperlayer()
            }
        }
    }
}
