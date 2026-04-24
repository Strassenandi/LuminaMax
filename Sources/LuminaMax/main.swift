import AppKit

/// Create and configure the application
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon

let delegate = AppDelegate()
app.delegate = delegate

// Run the application
app.run()
