import Cocoa

/// Handles touchpad and mouse gestures
class GestureHandler {
    private weak var layoutEngine: LayoutEngine?
    private var gestureMonitor: Any?
    private var localEventMonitor: Any?

    /// Reference to scanning mode controller for checking mode
    weak var scanningModeController: ScanningModeController?

    init(layoutEngine: LayoutEngine) {
        self.layoutEngine = layoutEngine
    }

    func setupGestureMonitoring() {
        // Monitor global scroll wheel events
        gestureMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
        }

        // Also monitor local events (when app is focused)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
            return event
        }

        print("Gesture monitoring enabled")
    }

    private func handleScrollEvent(_ event: NSEvent) {
        // Only process gestures when in scanning mode (Ctrl held)
        // This prevents accidental swipes during normal usage
        if let controller = scanningModeController, controller.mode != .scanning {
            return
        }

        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        let phase = event.phase
        let momentumPhase = event.momentumPhase

        // Only handle horizontal gestures
        guard abs(deltaX) > abs(deltaY) else {
            return
        }

        let isTouchpad = !phase.isEmpty || !momentumPhase.isEmpty
        let timestamp = event.timestamp

        // Handle momentum phase (inertia after finger lifts)
        // This provides smooth deceleration when the user releases the trackpad
        if !momentumPhase.isEmpty {
            switch momentumPhase {
            case .began:
                // Momentum started - continue the gesture with inertial scrolling
                // The gesture should already be active from the touch phase
                layoutEngine?.scrollingSpace?.viewOffsetGestureUpdate(
                    deltaX: deltaX,
                    timestamp: timestamp
                )

            case .changed:
                // Momentum continuing - update with decelerating deltas
                layoutEngine?.scrollingSpace?.viewOffsetGestureUpdate(
                    deltaX: deltaX,
                    timestamp: timestamp
                )

            case .ended, .cancelled:
                // Momentum ended - finalize the gesture
                layoutEngine?.scrollingSpace?.viewOffsetGestureEnd(cancelled: momentumPhase == .cancelled)

            default:
                break
            }
            return
        }

        // Handle touch phase (direct finger contact)
        switch phase {
        case .began:
            layoutEngine?.scrollingSpace?.viewOffsetGestureBegin(isTouchpad: isTouchpad)

        case .changed:
            layoutEngine?.scrollingSpace?.viewOffsetGestureUpdate(
                deltaX: deltaX,
                timestamp: timestamp
            )

        case .ended:
            // Don't end gesture here - wait for momentum phase if it will come
            // The momentum phase will handle the smooth deceleration
            // If no momentum follows, we'll snap immediately
            layoutEngine?.scrollingSpace?.viewOffsetGestureEnd(cancelled: false)

        case .cancelled:
            layoutEngine?.scrollingSpace?.viewOffsetGestureEnd(cancelled: true)

        default:
            // Handle mouse scroll (no phases)
            if phase.isEmpty && momentumPhase.isEmpty {
                layoutEngine?.scrollingSpace?.viewOffsetGestureBegin(isTouchpad: false)
                layoutEngine?.scrollingSpace?.viewOffsetGestureUpdate(
                    deltaX: deltaX,
                    timestamp: timestamp
                )
                layoutEngine?.scrollingSpace?.viewOffsetGestureEnd(cancelled: false)
            }
        }
    }

    deinit {
        if let monitor = gestureMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
