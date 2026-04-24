import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var overlayManager: OverlayManager?
    private var screenParametersObserver: NSObjectProtocol?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?

    deinit {
        cleanupMonitorsAndObservers()
    }

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
        if let overlayManager {
            statusBarController = StatusBarController(overlayManager: overlayManager)
        }

        // Register for screen change notifications
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.screenParametersDidChange(notification)
        }

        // Register global keyboard shortcut (⌥⌘B)
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanupMonitorsAndObservers()
        overlayManager?.deactivate()
    }

    private func screenParametersDidChange(_ notification: Notification) {
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

    private func cleanupMonitorsAndObservers() {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
        }

        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }

        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }
}
