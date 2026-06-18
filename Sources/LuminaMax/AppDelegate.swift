import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var overlayManager: OverlayManager?
    private var screenParametersObserver: NSObjectProtocol?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var willSleepObserver: NSObjectProtocol?
    private var didWakeObserver: NSObjectProtocol?
    private var screensDidSleepObserver: NSObjectProtocol?
    private var screensDidWakeObserver: NSObjectProtocol?

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

        // Register for sleep/wake notifications to suspend/resume the boost
        let workspaceNC = NSWorkspace.shared.notificationCenter

        willSleepObserver = workspaceNC.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.overlayManager?.suspendForSleep()
        }

        didWakeObserver = workspaceNC.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delay to allow displays to fully initialize after system wake
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.overlayManager?.resumeAfterWake()
            }
        }

        screensDidSleepObserver = workspaceNC.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.overlayManager?.suspendForSleep()
        }

        screensDidWakeObserver = workspaceNC.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delay to allow displays to fully initialize after screen wake
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.overlayManager?.resumeAfterWake()
            }
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
        if modifierFlags == [.option, .command], event.keyCode == 11 { // 11 = 'B'
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

        let workspaceNC = NSWorkspace.shared.notificationCenter
        if let willSleepObserver {
            workspaceNC.removeObserver(willSleepObserver)
            self.willSleepObserver = nil
        }
        if let didWakeObserver {
            workspaceNC.removeObserver(didWakeObserver)
            self.didWakeObserver = nil
        }
        if let screensDidSleepObserver {
            workspaceNC.removeObserver(screensDidSleepObserver)
            self.screensDidSleepObserver = nil
        }
        if let screensDidWakeObserver {
            workspaceNC.removeObserver(screensDidWakeObserver)
            self.screensDidWakeObserver = nil
        }
    }
}
