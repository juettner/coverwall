import ScreenSaver
import CoverwallShared

@objc(CoverwallSaverView)
public final class CoverwallSaverView: ScreenSaverView {
    private var mosaic: MosaicView!
    private var manifests = ManifestStore()
    private var lastManifestDate: Date?
    private var framesSinceManifestCheck = 0
    private var currentDensity: TileDensity = SharedSettings().tileDensity
    private lazy var sheet: ConfigSheetController = {
        let sheet = ConfigSheetController()
        sheet.onSave = { [weak self] in self?.applySettings() }
        return sheet
    }()

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let settings = SharedSettings()
        mosaic = MosaicView(frame: bounds)
        mosaic.autoresizingMask = [.width, .height]
        currentDensity = settings.tileDensity
        mosaic.configure(density: currentDensity)
        addSubview(mosaic)
        applySettings()
        loadManifest()
    }

    private func applySettings() {
        let settings = SharedSettings()
        animationTimeInterval = settings.flipInterval
        mosaic.showLabels = settings.showLabels
        if settings.tileDensity != currentDensity {
            currentDensity = settings.tileDensity
            mosaic.configure(density: settings.tileDensity)
        }
    }

    private func loadManifest() {
        lastManifestDate = manifests.lastModified
        if let manifest = manifests.read() {
            mosaic.setAlbums(manifest.albums, cache: CacheStore())
        } else {
            mosaic.setAlbums([], cache: CacheStore())
        }
    }

    public override func animateOneFrame() {
        mosaic.flipRandomTile()
        framesSinceManifestCheck += 1
        // ~1 manifest check per minute regardless of flip interval
        let checkEvery = max(1, Int(60.0 / animationTimeInterval))
        if framesSinceManifestCheck >= checkEvery {
            framesSinceManifestCheck = 0
            applySettings()
            if manifests.lastModified != lastManifestDate { loadManifest() }
        }
    }

    public override var hasConfigureSheet: Bool { true }
    public override var configureSheet: NSWindow? { sheet.window }
}

final class ConfigSheetController {
    let window: NSWindow
    var onSave: (() -> Void)?
    private let settings = SharedSettings()
    private let densityPopup = NSPopUpButton()
    private let intervalSlider = NSSlider(value: 4, minValue: 2, maxValue: 15,
                                          target: nil, action: nil)
    private let labelsCheckbox = NSButton(checkboxWithTitle: "Show artist/title on flip",
                                          target: nil, action: nil)

    init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
                          styleMask: [.titled], backing: .buffered, defer: false)

        densityPopup.addItems(withTitles: TileDensity.allCases.map(\.rawValue))
        densityPopup.selectItem(withTitle: settings.tileDensity.rawValue)
        intervalSlider.doubleValue = settings.flipInterval
        labelsCheckbox.state = settings.showLabels ? .on : .off

        let openButton = NSButton(title: "Open Coverwall Settings",
                                  target: self, action: #selector(openHelper))
        let okButton = NSButton(title: "OK", target: self, action: #selector(done))
        okButton.keyEquivalent = "\r"

        let grid = NSStackView(views: [
            labeledRow("Tile size", densityPopup),
            labeledRow("Flip every (s)", intervalSlider),
            labelsCheckbox,
            NSStackView(views: [openButton, okButton]),
        ])
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 12
        grid.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        window.contentView = grid
    }

    private func labeledRow(_ title: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        return NSStackView(views: [label, control])
    }

    @objc private func openHelper() {
        // Deep link: launches the helper if needed AND opens its Settings
        // window. Launching the app alone shows nothing — it's a faceless
        // menu-bar app.
        NSWorkspace.shared.open(URL(string: "coverwall://settings")!)
    }

    @objc private func done() {
        if let title = densityPopup.titleOfSelectedItem,
           let density = TileDensity(rawValue: title) {
            settings.tileDensity = density
        }
        settings.flipInterval = intervalSlider.doubleValue
        settings.showLabels = labelsCheckbox.state == .on
        onSave?()
        window.sheetParent?.endSheet(window)
    }
}
