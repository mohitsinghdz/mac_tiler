import Cocoa

/// Direction for navigation
enum Direction {
    case left, right, up, down
}

/// Main layout engine coordinating all window management
class LayoutEngine {
    static var shared: LayoutEngine?

    let windowController = WindowController()
    private(set) var scrollingSpace: ScrollingSpace?
    private var trackedWindows: Set<Window> = []

    /// Scanning mode controller for gesture activation
    let scanningModeController = ScanningModeController()

    /// Gesture handler (kept as property for lifecycle management)
    private var gestureHandler: GestureHandler?

    init() {
        // Initialize with main screen
        let mainScreen = NSScreen.main ?? NSScreen.screens[0]
        let workingArea = Self.computeWorkingArea(screen: mainScreen)

        self.scrollingSpace = ScrollingSpace(workingArea: workingArea)

        LayoutEngine.shared = self

        setupKeyboardShortcuts()
        setupScanningMode()
    }

    // MARK: - Scanning Mode Setup

    private func setupScanningMode() {
        // Start monitoring for Ctrl key
        scanningModeController.start()

        // Set up mode change callback
        scanningModeController.onModeChange = { [weak self] mode in
            switch mode {
            case .scanning:
                // Center the active window when entering scanning mode
                self?.scrollingSpace?.centerActiveColumn()
                self?.scrollingSpace?.applyLayout(animate: false)
            case .normal:
                // Ensure any in-progress gesture snaps to nearest column
                if let space = self?.scrollingSpace, space.viewOffset.isGesture {
                    space.viewOffsetGestureEnd(cancelled: false)
                }
            }
        }
    }

    /// Set up gesture handler with scanning mode integration
    func setupGestureHandler(_ handler: GestureHandler) {
        self.gestureHandler = handler
        handler.scanningModeController = scanningModeController
    }

    // MARK: - Working Area Calculation

    static func computeWorkingArea(screen: NSScreen) -> CGRect {
        var area = screen.visibleFrame  // Excludes menu bar and dock

        // Apply additional margins if configured
        // TODO: Load from config
        let margin: CGFloat = 0
        area.origin.x += margin
        area.origin.y += margin
        area.size.width -= margin * 2
        area.size.height -= margin * 2

        return area
    }

    // MARK: - Window Management

    func addWindow(_ window: Window) {
        guard !trackedWindows.contains(window) else {
            return
        }

        trackedWindows.insert(window)
        scrollingSpace?.addWindow(window)

        print("Added window: \(window.title) (\(window.appName))")
    }

    func removeWindow(_ window: Window) {
        guard trackedWindows.contains(window) else {
            return
        }

        trackedWindows.remove(window)
        scrollingSpace?.removeWindow(window)

        print("Removed window: \(window.title)")
    }

    func focusWindow(_ window: Window) {
        // Update focus in layout
        // TODO: Implement focus tracking
        windowController.focusWindow(window)
    }

    // MARK: - Navigation

    func focusDirection(_ direction: Direction) {
        let targetWindow: Window?

        switch direction {
        case .left:
            targetWindow = scrollingSpace?.focusLeft()
        case .right:
            targetWindow = scrollingSpace?.focusRight()
        case .up:
            targetWindow = scrollingSpace?.focusUp()
        case .down:
            targetWindow = scrollingSpace?.focusDown()
        }

        if let window = targetWindow {
            windowController.focusWindow(window)
        }
    }

    // MARK: - Animations

    func advanceAnimations() {
        scrollingSpace?.advanceAnimations()

        // Apply layout if in gesture or animation
        if scrollingSpace?.needsLayoutUpdate() == true {
            scrollingSpace?.applyLayout(animate: false)
        }
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        // Setup CGEventTap for keyboard shortcuts
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let engine = Unmanaged<LayoutEngine>.fromOpaque(refcon!).takeUnretainedValue()
                return engine.handleKeyEvent(event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("Failed to create event tap")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handleKeyEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Check for Cmd+Option modifier
        let hasModifier = flags.contains(.maskCommand) && flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)

        guard hasModifier else {
            return Unmanaged.passRetained(event)
        }

        // H: Focus left (keycode 4)
        // L: Focus right (keycode 37)
        // K: Focus up (keycode 40)
        // J: Focus down (keycode 38)
        // With Shift: Move window to new column

        switch keyCode {
        case 4:  // H
            if hasShift {
                // Cmd+Option+Shift+H: Move window to new column left
                if let window = scrollingSpace?.activeWindow {
                    scrollingSpace?.moveWindowToNewColumn(window, direction: .left)
                }
            } else {
                focusDirection(.left)
            }
            return nil  // Consume event
        case 37:  // L
            if hasShift {
                // Cmd+Option+Shift+L: Move window to new column right
                if let window = scrollingSpace?.activeWindow {
                    scrollingSpace?.moveWindowToNewColumn(window, direction: .right)
                }
            } else {
                focusDirection(.right)
            }
            return nil
        case 40:  // K
            focusDirection(.up)
            return nil
        case 38:  // J
            focusDirection(.down)
            return nil
        default:
            break
        }

        return Unmanaged.passRetained(event)
    }
}
