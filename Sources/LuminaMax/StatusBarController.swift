import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem
    private var overlayManager: OverlayManager
    private var brightnessSlider: NSSlider?
    private var edrInfoItem: NSMenuItem?
    private var toggleItem: NSMenuItem?
    private var brightnessLabel: NSMenuItem?

    init(overlayManager: OverlayManager) {
        self.overlayManager = overlayManager

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use SF Symbol for the sun icon
            if let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "LuminaMax") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "☀️"
            }
            button.toolTip = "LuminaMax – XDR Brightness Boost"
        }

        // Build the menu
        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Title
        let titleItem = NSMenuItem(title: "LuminaMax", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        if let font = NSFont.boldSystemFont(ofSize: 13) as NSFont? {
            titleItem.attributedTitle = NSAttributedString(
                string: "☀️ LuminaMax",
                attributes: [.font: font]
            )
        }
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // EDR Info
        let edrInfoItem = NSMenuItem(title: "EDR Headroom: --", action: nil, keyEquivalent: "")
        edrInfoItem.isEnabled = false
        self.edrInfoItem = edrInfoItem
        menu.addItem(edrInfoItem)
        updateEDRInfo()

        menu.addItem(NSMenuItem.separator())

        // Toggle
        let toggleItem = NSMenuItem(
            title: "Brightness Boost: Aus",
            action: #selector(toggleBrightness),
            keyEquivalent: "b"
        )
        toggleItem.keyEquivalentModifierMask = [.option, .command]
        toggleItem.target = self
        self.toggleItem = toggleItem
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Brightness label
        let brightnessLabel = NSMenuItem(title: "Intensität: 100%", action: nil, keyEquivalent: "")
        brightnessLabel.isEnabled = false
        self.brightnessLabel = brightnessLabel
        menu.addItem(brightnessLabel)

        // Brightness Slider
        let sliderItem = NSMenuItem()
        let sliderView = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))

        let slider = NSSlider(frame: NSRect(x: 20, y: 5, width: 180, height: 20))
        slider.minValue = 0.0
        slider.maxValue = 1.0
        slider.doubleValue = overlayManager.brightnessNormalized
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.controlSize = .regular

        sliderView.addSubview(slider)
        sliderItem.view = sliderView
        brightnessSlider = slider
        menu.addItem(sliderItem)

        // Preset buttons
        menu.addItem(NSMenuItem.separator())

        let preset50 = NSMenuItem(title: "  50% Boost", action: #selector(setPreset50), keyEquivalent: "")
        preset50.target = self
        menu.addItem(preset50)

        let preset75 = NSMenuItem(title: "  75% Boost", action: #selector(setPreset75), keyEquivalent: "")
        preset75.target = self
        menu.addItem(preset75)

        let preset100 = NSMenuItem(title: "  100% Boost (Maximum)", action: #selector(setPreset100), keyEquivalent: "")
        preset100.target = self
        menu.addItem(preset100)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Beenden",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleBrightness() {
        overlayManager.toggle()
        updateToggleState()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        overlayManager.brightnessNormalized = value
        updateBrightnessLabel()
    }

    @objc private func setPreset50() {
        overlayManager.brightnessNormalized = 0.5
        brightnessSlider?.doubleValue = 0.5
        updateBrightnessLabel()
    }

    @objc private func setPreset75() {
        overlayManager.brightnessNormalized = 0.75
        brightnessSlider?.doubleValue = 0.75
        updateBrightnessLabel()
    }

    @objc private func setPreset100() {
        overlayManager.brightnessNormalized = 1.0
        brightnessSlider?.doubleValue = 1.0
        updateBrightnessLabel()
    }

    @objc private func quitApp() {
        overlayManager.deactivate()
        NSApplication.shared.terminate(nil)
    }

    func updateToggleState() {
        if overlayManager.isActive {
            toggleItem?.title = "Brightness Boost: An ✓"
            if let button = statusItem.button {
                if let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "LuminaMax Active") {
                    image.isTemplate = false
                    // Tint the icon to indicate active state
                    let config = NSImage.SymbolConfiguration(paletteColors: [.systemYellow])
                    if let tintedImage = image.withSymbolConfiguration(config) {
                        button.image = tintedImage
                    } else {
                        button.image = image
                    }
                }
            }
        } else {
            toggleItem?.title = "Brightness Boost: Aus"
            if let button = statusItem.button {
                if let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "LuminaMax") {
                    image.isTemplate = true
                    button.image = image
                }
            }
        }
    }

    func updateEDRInfo() {
        guard let screen = NSScreen.main else { return }
        let current = screen.maximumExtendedDynamicRangeColorComponentValue
        let potential = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
        edrInfoItem?.title = String(format: "EDR: %.1fx aktuell / %.1fx max", current, potential)
    }

    private func updateBrightnessLabel() {
        let percentage = Int(overlayManager.brightnessNormalized * 100)
        brightnessLabel?.title = "Intensität: \(percentage)%"
    }
}
