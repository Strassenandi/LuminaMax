import AppKit
import Metal

class OverlayManager {
    
    private var overlayWindows: [CGDirectDisplayID: NSWindow] = [:]
    private var renderers: [CGDirectDisplayID: MetalRenderer] = [:]
    private var baselineGammaTables: [CGDirectDisplayID: GammaTable] = [:]
    
    // Fade animation state
    private var fadeTimer: Timer?
    private var currentFadeFactor: Float = 1.0  // Current interpolated gamma factor
    private var targetFadeFactor: Float = 1.0   // Where we're fading to
    private let fadeStepDuration: TimeInterval = 1.0 / 60.0  // ~60fps fade
    private let fadeDuration: TimeInterval = 0.6  // Total fade time in seconds
    private var fadeStartFactor: Float = 1.0
    private var fadeStartTime: Date?
    
    private(set) var isActive: Bool = false {
        didSet {
            UserDefaults.standard.set(isActive, forKey: "isActive")
        }
    }
    
    /// Normalized brightness from 0.0 to 1.0, where 1.0 = maximum EDR boost
    var brightnessNormalized: Double = 1.0 {
        didSet {
            brightnessNormalized = max(0.0, min(1.0, brightnessNormalized))
            UserDefaults.standard.set(brightnessNormalized, forKey: "brightnessNormalized")
            if isActive {
                updateTargetGamma()
            }
        }
    }
    
    init() {
        // Restore saved settings
        if UserDefaults.standard.object(forKey: "brightnessNormalized") != nil {
            brightnessNormalized = UserDefaults.standard.double(forKey: "brightnessNormalized")
        }
        
        // If was previously active, reactivate
        if UserDefaults.standard.bool(forKey: "isActive") {
            activate()
        }
    }
    
    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }
    
    func activate() {
        guard !isActive else { return }
        isActive = true
        
        // Reset fade state — start from neutral
        currentFadeFactor = 1.0
        
        // Create overlays for all XDR-capable screens
        for screen in NSScreen.screens {
            createOverlay(for: screen)
        }
        
        // Start polling for EDR readiness
        pollForEDR()
    }
    
    func deactivate() {
        guard isActive else { return }
        
        // Fade out smoothly before tearing down
        // Set inactive IMMEDIATELY so polling/update loops stop
        isActive = false
        
        // Fade out smoothly before tearing down
        fadeToFactor(1.0) { [weak self] in
            guard let self = self else { return }
            self.stopFade()
            
            // Remove all overlay windows
            for (_, window) in self.overlayWindows {
                window.orderOut(nil)
                window.close()
            }
            self.overlayWindows.removeAll()
            self.renderers.removeAll()
            
            // Restore gamma tables
            for (displayId, table) in self.baselineGammaTables {
                table.restore(displayId: displayId)
            }
            self.baselineGammaTables.removeAll()
            CGDisplayRestoreColorSyncSettings()
        }
    }
    
    func updateForScreenChange() {
        guard isActive else { return }
        
        stopFade()
        
        // Remove old overlays
        for (_, window) in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
        renderers.removeAll()
        
        // Restore gamma before recreating
        for (displayId, table) in baselineGammaTables {
            table.restore(displayId: displayId)
        }
        baselineGammaTables.removeAll()
        CGDisplayRestoreColorSyncSettings()
        
        // Reset fade state
        currentFadeFactor = 1.0
        
        // Recreate for current screens
        for screen in NSScreen.screens {
            createOverlay(for: screen)
        }
        
        pollForEDR()
    }
    
    private func createOverlay(for screen: NSScreen) {
        guard let displayId = screen.displayId else { return }
        
        // Save baseline gamma table before we modify anything
        if baselineGammaTables[displayId] == nil,
           let table = GammaTable.captureCurrentGamma(displayId: displayId) {
            baselineGammaTables[displayId] = table
        }
        
        // Create a tiny 1x1 window — this is all that's needed to trigger EDR
        let windowRect = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y + screen.frame.height - 1,
            width: 1,
            height: 1
        )
        
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        // Configure as invisible, non-interactive overlay
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .screenSaver
        window.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.canHide = false
        window.alphaValue = 1
        
        // Create the Metal EDR renderer (1x1 pixel MTKView)
        guard let renderer = MetalRenderer(screen: screen) else {
            print("Failed to create MetalRenderer for display: \(displayId)")
            return
        }
        
        renderer.autoresizingMask = [.width, .height]
        window.contentView = renderer
        window.orderFrontRegardless()
        
        overlayWindows[displayId] = window
        renderers[displayId] = renderer
    }
    
    // MARK: - EDR Polling
    
    private func pollForEDR() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.isActive else { return }
            
            var anyReady = false
            for screen in NSScreen.screens {
                let edr = screen.maximumExtendedDynamicRangeColorComponentValue
                if edr > 1.05 {
                    anyReady = true
                    break
                }
            }
            
            if anyReady {
                // EDR is ready — fade in smoothly to target brightness
                self.updateTargetGamma()
                // Continue monitoring
                self.continuousGammaUpdate()
            } else {
                // Keep polling
                self.pollForEDR()
            }
        }
    }
    
    private func continuousGammaUpdate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.isActive else { return }
            // Recalculate target in case EDR headroom changed
            self.updateTargetGamma()
            self.continuousGammaUpdate()
        }
    }
    
    // MARK: - Smooth Gamma Fade
    
    /// Calculate the target gamma factor and start fading towards it
    private func updateTargetGamma() {
        // Find the maximum available EDR headroom across screens
        var maxFactor: Float = 1.0
        for screen in NSScreen.screens {
            guard let displayId = screen.displayId,
                  baselineGammaTables[displayId] != nil else { continue }
            
            let maxEDR = screen.maximumExtendedDynamicRangeColorComponentValue
            guard maxEDR > 1.0 else { continue }
            
            let factor = 1.0 + (Float(brightnessNormalized) * (Float(maxEDR) / 4.0))
            maxFactor = max(maxFactor, factor)
        }
        
        fadeToFactor(maxFactor)
    }
    
    /// Start a smooth fade from the current factor to the target
    private func fadeToFactor(_ target: Float, completion: (() -> Void)? = nil) {
        // If already very close, just snap
        if abs(currentFadeFactor - target) < 0.005 {
            currentFadeFactor = target
            applyGammaWithFactor(target)
            completion?()
            return
        }
        
        targetFadeFactor = target
        fadeStartFactor = currentFadeFactor
        fadeStartTime = Date()
        
        // Stop any existing fade
        fadeTimer?.invalidate()
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeStepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            guard let startTime = self.fadeStartTime else {
                timer.invalidate()
                completion?()
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            var progress = Float(elapsed / self.fadeDuration)
            
            if progress >= 1.0 {
                // Fade complete
                progress = 1.0
                timer.invalidate()
                self.fadeTimer = nil
                self.fadeStartTime = nil
                self.currentFadeFactor = self.targetFadeFactor
                self.applyGammaWithFactor(self.targetFadeFactor)
                completion?()
                return
            }
            
            // Ease-in-out curve for smooth transition: smoothstep
            let t = progress
            let eased = t * t * (3.0 - 2.0 * t)
            
            self.currentFadeFactor = self.fadeStartFactor + (self.targetFadeFactor - self.fadeStartFactor) * eased
            self.applyGammaWithFactor(self.currentFadeFactor)
        }
    }
    
    private func stopFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        fadeStartTime = nil
    }
    
    /// Apply the given gamma factor to all active displays
    private func applyGammaWithFactor(_ factor: Float) {
        for screen in NSScreen.screens {
            guard let displayId = screen.displayId,
                  let baseTable = baselineGammaTables[displayId] else { continue }
            
            baseTable.apply(displayId: displayId, factor: factor)
        }
    }
}

// MARK: - NSScreen Display ID Extension

extension NSScreen {
    var displayId: CGDirectDisplayID? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }
}

// MARK: - Gamma Table Management

class GammaTable {
    static let tableSize: UInt32 = 256
    
    var redTable: [CGGammaValue]
    var greenTable: [CGGammaValue]
    var blueTable: [CGGammaValue]
    
    private init(red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue]) {
        self.redTable = red
        self.greenTable = green
        self.blueTable = blue
    }
    
    static func captureCurrentGamma(displayId: CGDirectDisplayID) -> GammaTable? {
        var redTable = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var greenTable = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var blueTable = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var sampleCount: UInt32 = 0
        
        let result = CGGetDisplayTransferByTable(
            displayId,
            tableSize,
            &redTable,
            &greenTable,
            &blueTable,
            &sampleCount
        )
        
        guard result == .success else {
            print("Failed to capture gamma table for display \(displayId)")
            return nil
        }
        
        return GammaTable(red: redTable, green: greenTable, blue: blueTable)
    }
    
    func apply(displayId: CGDirectDisplayID, factor: Float = 1.0) {
        var newRed = redTable
        var newGreen = greenTable
        var newBlue = blueTable
        
        for i in 0..<redTable.count {
            newRed[i] = min(redTable[i] * factor, 1.0)
            newGreen[i] = min(greenTable[i] * factor, 1.0)
            newBlue[i] = min(blueTable[i] * factor, 1.0)
        }
        
        CGSetDisplayTransferByTable(displayId, GammaTable.tableSize, &newRed, &newGreen, &newBlue)
    }
    
    func restore(displayId: CGDirectDisplayID) {
        var red = redTable
        var green = greenTable
        var blue = blueTable
        CGSetDisplayTransferByTable(displayId, GammaTable.tableSize, &red, &green, &blue)
    }
}
