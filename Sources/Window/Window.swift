import Cocoa
import ApplicationServices

/// Represents a window in the system
class Window: Hashable, Equatable {
    typealias ID = UInt32

    let id: ID
    let axElement: AXUIElement
    let app: NSRunningApplication

    private(set) var cachedFrame: CGRect?
    private(set) var cachedTitle: String?

    init(axElement: AXUIElement, app: NSRunningApplication) {
        // Get window ID from AX element
        var windowID: CGWindowID = 0
        _ = _AXUIElementGetWindow(axElement, &windowID)

        self.id = windowID
        self.axElement = axElement
        self.app = app

        // Cache initial values
        self.cachedFrame = getFrame()
        self.cachedTitle = getTitle()
    }

    // MARK: - Properties

    var title: String {
        if let cached = cachedTitle {
            return cached
        }

        let title = getTitle()
        cachedTitle = title
        return title
    }

    var currentFrame: CGRect {
        if let cached = cachedFrame {
            return cached
        }

        let frame = getFrame()
        cachedFrame = frame
        return frame
    }

    var appName: String {
        return app.localizedName ?? "Unknown"
    }

    var bundleIdentifier: String? {
        return app.bundleIdentifier
    }

    // MARK: - Private Helpers

    private func getFrame() -> CGRect {
        guard let position = getPosition(),
              let size = getSize() else {
            return .zero
        }

        return CGRect(origin: position, size: size)
    }

    private func getPosition() -> CGPoint? {
        var positionRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            axElement,
            kAXPositionAttribute as CFString,
            &positionRef
        )

        guard result == .success,
              let positionValue = positionRef else {
            return nil
        }

        var point = CGPoint.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &point)
        return point
    }

    private func getSize() -> CGSize? {
        var sizeRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            axElement,
            kAXSizeAttribute as CFString,
            &sizeRef
        )

        guard result == .success,
              let sizeValue = sizeRef else {
            return nil
        }

        var size = CGSize.zero
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return size
    }

    private func getTitle() -> String {
        var titleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            axElement,
            kAXTitleAttribute as CFString,
            &titleRef
        )

        guard result == .success,
              let title = titleRef as? String else {
            return ""
        }

        return title
    }

    // MARK: - State Management

    func invalidateCache() {
        cachedFrame = nil
        cachedTitle = nil
    }

    func isMaximizable() -> Bool {
        // Check window role - must be a standard window
        var roleRef: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXRoleAttribute as CFString,
            &roleRef
        )

        if roleResult == .success, let role = roleRef as? String {
            // Only accept actual windows
            if role != "AXWindow" {
                return false
            }
        } else {
            // Can't determine role - reject to be safe
            return false
        }

        // Check subrole - reject utility windows
        var subroleRef: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSubroleAttribute as CFString,
            &subroleRef
        )

        if subroleResult == .success, let subrole = subroleRef as? String {
            // Reject dialogs, sheets, floating windows
            let rejectedSubroles = [
                "AXDialog", "AXSystemDialog", "AXSheet",
                "AXFloatingWindow", "AXUnknown"
            ]
            if rejectedSubroles.contains(subrole) {
                return false
            }
        }

        // Try to get window position to verify it's real
        var posRef: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXPositionAttribute as CFString,
            &posRef
        )

        // Accept if we can get position (standard window)
        return posResult == .success
    }

    // MARK: - Hashable & Equatable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Window, rhs: Window) -> Bool {
        return lhs.id == rhs.id
    }
}

// Private C function declaration
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError
