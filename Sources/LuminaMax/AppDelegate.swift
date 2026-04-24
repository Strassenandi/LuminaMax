import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController?
    private var overlayManager: OverlayManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if the display supports XDR/EDR
        guard let screen = NSScreen.main else {
            showAlert(
                title: "Kein Display gefunden",
                message: "LuminaMax konnte kein Display erkennen."
            )
            return
        }
        
        let potentialEDR = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
        if potentialEDR <= 1.0 {
            showAlert(
                title: "XDR Display nicht erkannt",
                message: "Dein Display unterstützt kein Extended Dynamic Range (EDR). LuminaMax funktioniert nur mit XDR-Displays (MacBook Pro M1 Pro/Max oder neuer).\n\nPotentieller EDR-Wert: \(potentialEDR)"
            )
        }
        
        // Initialize the overlay manager
        overlayManager = OverlayManager()
        
        // Initialize the status bar controller
        statusBarController = StatusBarController(overlayManager: overlayManager!)
        
        // Register for screen change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Register global keyboard shortcut (⌥⌘B)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
            return event
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        overlayManager?.deactivate()
    }
    
    @objc private func screenParametersDidChange(_ notification: Notification) {
        overlayManager?.updateForScreenChange()
        statusBarController?.updateEDRInfo()
    }
    
    private func handleGlobalKeyEvent(_ event: NSEvent) {
        // ⌥⌘B (Option + Command + B)
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifierFlags == [.option, .command] && event.keyCode == 11 { // 11 = 'B'
            overlayManager?.toggle()
            statusBarController?.updateToggleState()
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
