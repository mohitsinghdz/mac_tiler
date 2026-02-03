import Cocoa
import CoreGraphics

/// Handles touchpad and mouse gestures
class GestureHandler {
    private weak var layoutEngine: LayoutEngine?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Reference to scanning mode controller for checking mode
    weak var scanningModeController: ScanningModeController?

    init(layoutEngine: LayoutEngine) {
        self.layoutEngine = layoutEngine
    }

    func setupGestureMonitoring() {
        // Create event tap to intercept AND block scroll events when in scanning mode
        let eventMask = (1 << CGEventType.scrollWheel.rawValue)

        // Store self in a pointer for the callback
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,  // Can modify/block events
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                let handler = Unmanaged<GestureHandler>.fromOpaque(refcon).takeUnretainedValue()
                return handler.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            print("Failed to create event tap for gestures")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        print("Gesture event tap enabled")
    }

    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // If not in scanning mode, pass event through unchanged
        guard let controller = scanningModeController, controller.mode == .scanning else {
            return Unmanaged.passRetained(event)
        }

        // Convert to NSEvent for easier handling
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passRetained(event)
        }

        let deltaX = nsEvent.scrollingDeltaX
        let deltaY = nsEvent.scrollingDeltaY
        let phase = nsEvent.phase
        let momentumPhase = nsEvent.momentumPhase

        // Only handle horizontal gestures - pass vertical through
        guard abs(deltaX) > abs(deltaY) else {
            return Unmanaged.passRetained(event)
        }

        let isTouchpad = !phase.isEmpty || !momentumPhase.isEmpty
        let timestamp = nsEvent.timestamp

        // Handle momentum phase (inertia after finger lifts)
        if !momentumPhase.isEmpty {
            switch momentumPhase {
            case .began, .changed:
                layoutEngine?.scrollingSpace?.viewOffsetGestureUpdate(
                    deltaX: deltaX,
                    timestamp: timestamp
                )

            case .ended, .cancelled:
                layoutEngine?.scrollingSpace?.viewOffsetGestureEnd(cancelled: momentumPhase == .cancelled)

            default:
                break
            }
            // Block the event - don't pass to windows
            return nil
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

        // Block the event - don't pass to windows
        return nil
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }
}
