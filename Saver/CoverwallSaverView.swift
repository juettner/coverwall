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
    public override var configureSheet: NSWindow? {
        sheet.refresh()
        return sheet.window
    }
}

final class ConfigSheetController {
    let window: NSWindow
    var onSave: (() -> Void)?
    private let settings = SharedSettings()
    private let densityPopup = NSPopUpButton()
    private let intervalSlider = NSSlider(value: 4, minValue: 2, maxValue: 15,
                                          target: nil, action: nil)
    private let intervalValueLabel = NSTextField(labelWithString: "")
    private let labelsCheckbox = NSButton(checkboxWithTitle: "Show artist and title when a tile flips",
                                          target: nil, action: nil)

    private static let densityTitles: [(TileDensity, String)] =
        [(.small, "Small"), (.medium, "Medium"), (.large, "Large")]

    init() {
        window = NSWindow(contentRect: .zero, styleMask: [.titled],
                          backing: .buffered, defer: false)

        densityPopup.addItems(withTitles: Self.densityTitles.map(\.1))

        intervalSlider.target = self
        intervalSlider.action = #selector(intervalChanged)
        intervalSlider.allowsTickMarkValuesOnly = true
        intervalSlider.numberOfTickMarks = 27  // 2...15 in 0.5s steps
        intervalSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        intervalValueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize,
                                                             weight: .regular)
        intervalValueLabel.textColor = .secondaryLabelColor
        intervalValueLabel.alignment = .right
        intervalValueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let sliderRow = NSStackView(views: [intervalSlider, intervalValueLabel])
        sliderRow.spacing = 8

        let grid = NSGridView(views: [
            [label("Tile size:"), densityPopup],
            [label("Flip every:"), sliderRow],
            [NSGridCell.emptyContentView, labelsCheckbox],
        ])
        grid.rowSpacing = 10
        grid.column(at: 0).xPlacement = .trailing

        let openButton = NSButton(title: "Open Coverwall Settings…",
                                  target: self, action: #selector(openHelper))
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        let okButton = NSButton(title: "OK", target: self, action: #selector(done))
        okButton.keyEquivalent = "\r"

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttonRow = NSStackView(views: [openButton, spacer, cancelButton, okButton])
        buttonRow.spacing = 8

        let content = NSStackView(views: [grid, buttonRow])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 16
        content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 16, right: 20)
        buttonRow.widthAnchor.constraint(equalTo: content.widthAnchor,
                                         constant: -40).isActive = true

        window.contentView = content
        refresh()
        window.setContentSize(content.fittingSize)
    }

    /// Re-syncs controls from SharedSettings; called every time the sheet is
    /// requested so a reopened sheet never shows stale values.
    func refresh() {
        let density = settings.tileDensity
        if let index = Self.densityTitles.firstIndex(where: { $0.0 == density }) {
            densityPopup.selectItem(at: index)
        }
        intervalSlider.doubleValue = settings.flipInterval
        labelsCheckbox.state = settings.showLabels ? .on : .off
        updateIntervalLabel()
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    @objc private func intervalChanged() {
        updateIntervalLabel()
    }

    private func updateIntervalLabel() {
        let value = intervalSlider.doubleValue
        intervalValueLabel.stringValue = value == value.rounded()
            ? "\(Int(value)) s"
            : String(format: "%.1f s", value)
    }

    @objc private func openHelper() {
        // Deep link: launches the helper if needed AND opens its Settings
        // window. Launching the app alone shows nothing — it's a faceless
        // menu-bar app.
        NSWorkspace.shared.open(URL(string: "coverwall://settings")!)
    }

    @objc private func cancel() {
        window.sheetParent?.endSheet(window)
    }

    @objc private func done() {
        let index = densityPopup.indexOfSelectedItem
        if Self.densityTitles.indices.contains(index) {
            settings.tileDensity = Self.densityTitles[index].0
        }
        settings.flipInterval = intervalSlider.doubleValue
        settings.showLabels = labelsCheckbox.state == .on
        onSave?()
        window.sheetParent?.endSheet(window)
    }
}
