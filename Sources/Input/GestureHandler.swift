import Cocoa
import CoreGraphics

/// Scroll direction being tracked during a gesture
private enum ScrollDirection {
    case undetermined
    case horizontal
    case vertical
}

/// Handles touchpad and mouse gestures
class GestureHandler {
    private weak var layoutEngine: LayoutEngine?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Reference to scanning mode controller for checking mode
    weak var scanningModeController: ScanningModeController?

    /// Current scroll direction (locked once determined during a gesture)
    private var scrollDirection: ScrollDirection = .undetermined

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

        let isTouchpad = !phase.isEmpty || !momentumPhase.isEmpty
        let timestamp = nsEvent.timestamp

        // Determine scroll direction at gesture begin (with hysteresis)
        if phase == .began || (phase.isEmpty && momentumPhase.isEmpty && scrollDirection == .undetermined) {
            scrollDirection = .undetermined
        }

        // Lock in direction once determined (prevents diagonal jitter)
        if scrollDirection == .undetermined {
            let absX = abs(deltaX)
            let absY = abs(deltaY)

            // Use hysteresis to determine dominant direction
            if absX > absY * 1.5 {
                scrollDirection = .horizontal
            } else if absY > absX * 1.5 {
                scrollDirection = .vertical
            } else if absX > 1.0 || absY > 1.0 {
                // If both similar magnitude, pick the larger one
                scrollDirection = absX > absY ? .horizontal : .vertical
            }
        }

        // If direction still undetermined (very small deltas), pass through
        guard scrollDirection != .undetermined else {
            return Unmanaged.passRetained(event)
        }

        // Handle momentum phase (inertia after finger lifts)
        if !momentumPhase.isEmpty {
            switch momentumPhase {
            case .began, .changed:
                if scrollDirection == .horizontal {
                    layoutEngine?.scrollingSpace?.viewOffsetGestureUpdate(
                        deltaX: deltaX,
                        timestamp: timestamp
                    )
                } else {
                    layoutEngine?.scrollingSpace?.verticalOffsetGestureUpdate(
                        deltaY: deltaY,
                        timestamp: timestamp
                    )
                }

            case .ended, .cancelled:
                let cancelled = momentumPhase == .cancelled
                if scrollDirection == .horizontal {
                    layoutEngine?.scrollingSpace?.viewOffsetGestureEnd(cancelled: cancelled)
                } else {
                    layoutEngine?.scrollingSpace?.verticalOffsetGestureEnd(cancelled: cancelled)
                }
                scrollDirection = .undetermined

            default:
                break
            }
            // Block the event - don't pass to windows
            return nil
        }

        // Handle touch phase (direct finger contact)
        switch phase {
        case .began:
            if scrollDirection == .horizontal {
                layoutEngine?.scrollingSpace?.viewOffsetGestureBegin(isTouchpad: isTouchpad)
            } else {
                layoutEngine?.scrollingSpace?.verticalOffsetGestureBegin(isTouchpad: isTouchpad)
            }

        case .changed:
            if scrollDirection == .horizontal {
                layoutEngine?.scrollingSpace?.viewOffsetGestureUpdate(
                    deltaX: deltaX,
                    timestamp: timestamp
                )
            } else {
                layoutEngine?.scrollingSpace?.verticalOffsetGestureUpdate(
                    deltaY: deltaY,
                    timestamp: timestamp
                )
            }

        case .ended:
            if scrollDirection == .horizontal {
                layoutEngine?.scrollingSpace?.viewOffsetGestureEnd(cancelled: false)
            } else {
                layoutEngine?.scrollingSpace?.verticalOffsetGestureEnd(cancelled: false)
            }
            scrollDirection = .undetermined

        case .cancelled:
            if scrollDirection == .horizontal {
                layoutEngine?.scrollingSpace?.viewOffsetGestureEnd(cancelled: true)
            } else {
                layoutEngine?.scrollingSpace?.verticalOffsetGestureEnd(cancelled: true)
            }
            scrollDirection = .undetermined

        default:
            // Handle mouse scroll (no phases)
            if phase.isEmpty && momentumPhase.isEmpty {
                if scrollDirection == .horizontal {
                    layoutEngine?.scrollingSpace?.viewOffsetGestureBegin(isTouchpad: false)
                    layoutEngine?.scrollingSpace?.viewOffsetGestureUpdate(
                        deltaX: deltaX,
                        timestamp: timestamp
                    )
                    layoutEngine?.scrollingSpace?.viewOffsetGestureEnd(cancelled: false)
                } else {
                    layoutEngine?.scrollingSpace?.verticalOffsetGestureBegin(isTouchpad: false)
                    layoutEngine?.scrollingSpace?.verticalOffsetGestureUpdate(
                        deltaY: deltaY,
                        timestamp: timestamp
                    )
                    layoutEngine?.scrollingSpace?.verticalOffsetGestureEnd(cancelled: false)
                }
                scrollDirection = .undetermined
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
