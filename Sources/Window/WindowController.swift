import Cocoa
import ApplicationServices

/// Controls window positioning and sizing via Accessibility API
class WindowController {

    /// Set window frame with optional animation
    func setWindowFrame(_ window: Window, frame: CGRect, animate: Bool) {
        // Skip if frame hasn't changed significantly (includes rate limiting)
        guard WindowCache.shared.shouldUpdateFrame(window, to: frame) else {
            return
        }

        // Check if only position changed (common during scrolling)
        let onlyPositionChanged = WindowCache.shared.onlyPositionChanged(window, to: frame)

        // Set position
        var position = frame.origin
        let posValue = AXValueCreate(.cgPoint, &position)!
        let posResult = AXUIElementSetAttributeValue(
            window.axElement,
            kAXPositionAttribute as CFString,
            posValue
        )

        // Only set size if it actually changed (reduces flickering during scroll)
        var sizeResult: AXError = .success
        if !onlyPositionChanged {
            var size = frame.size
            let sizeValue = AXValueCreate(.cgSize, &size)!
            sizeResult = AXUIElementSetAttributeValue(
                window.axElement,
                kAXSizeAttribute as CFString,
                sizeValue
            )
        }

        // Update cache
        window.invalidateCache()
        WindowCache.shared.updateFrame(window, frame: frame)

        // Handle failures with fallback (only if both failed)
        if posResult != .success && sizeResult != .success {
            fallbackPositioning(window, frame)
        }
    }

    /// Fallback positioning using AppleScript (for apps that ignore AX)
    private func fallbackPositioning(_ window: Window, _ frame: CGRect) {
        guard let appName = window.app.localizedName else { return }

        // Convert from Cocoa coordinates to AppleScript coordinates
        // macOS: origin at bottom-left, AppleScript: origin at top-left
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let y = screenHeight - frame.maxY

        let script = """
        tell application "\(appName)"
            try
                set bounds of window 1 to {\(Int(frame.minX)), \(Int(y)), \(Int(frame.maxX)), \(Int(y + frame.height))}
            end try
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)

            if let error = error {
                print("AppleScript fallback failed: \(error)")
            }
        }
    }

    /// Focus a window (bring to front)
    func focusWindow(_ window: Window) {
        // Raise window
        AXUIElementSetAttributeValue(
            window.axElement,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )

        // Focus window
        AXUIElementSetAttributeValue(
            window.axElement,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )

        // Activate application
        window.app.activate(options: [.activateIgnoringOtherApps])
    }
}
