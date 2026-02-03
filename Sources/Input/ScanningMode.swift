import Cocoa

/// Navigation mode state machine
enum NavigationMode {
    case normal     // Regular operation - gestures ignored
    case scanning   // Holding activation key - swipe navigates between windows
}

/// Controls scanning mode activation and deactivation
/// Hold Ctrl to enter scanning mode, release to confirm selection
class ScanningModeController {
    private(set) var mode: NavigationMode = .normal

    private var flagsMonitor: Any?
    private var localFlagsMonitor: Any?

    /// The modifier key that activates scanning mode
    /// Default is Control key
    var activationModifier: NSEvent.ModifierFlags = .control

    /// Callback when mode changes
    var onModeChange: ((NavigationMode) -> Void)?

    /// Start monitoring for activation key
    func start() {
        // Monitor global flags changed events (modifier keys)
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .flagsChanged
        ) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // Also monitor local events (when app is focused)
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .flagsChanged
        ) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    /// Stop monitoring
    func stop() {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags

        // Check if activation modifier is pressed
        let isActivationKeyPressed = flags.contains(activationModifier)

        if isActivationKeyPressed && mode == .normal {
            enterScanningMode()
        } else if !isActivationKeyPressed && mode == .scanning {
            exitScanningMode()
        }
    }

    private func enterScanningMode() {
        mode = .scanning
        NSLog("NiriMacOS: Entered scanning mode (Ctrl held)")
        onModeChange?(.scanning)
    }

    private func exitScanningMode() {
        mode = .normal
        NSLog("NiriMacOS: Exited scanning mode (Ctrl released)")
        onModeChange?(.normal)
    }

    deinit {
        stop()
    }
}
