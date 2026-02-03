import Foundation

/// View offset state machine (ported from niri/src/layout/scrolling.rs)
enum ViewOffset {
    case `static`(Double)
    case animation(ViewOffsetAnimation)
    case gesture(ViewGesture)

    var isStatic: Bool {
        if case .static = self { return true }
        return false
    }

    var isGesture: Bool {
        if case .gesture = self { return true }
        return false
    }
}

/// Animated view offset transition
struct ViewOffsetAnimation {
    let spring: Spring
    let startTime: TimeInterval

    func value(at time: TimeInterval) -> Double {
        return spring.valueAt(time)
    }

    func velocity(at time: TimeInterval) -> Double {
        return spring.velocityAt(time)
    }

    func isDone(at time: TimeInterval) -> Bool {
        return spring.isDone(time)
    }
}

/// Gesture-driven view offset
struct ViewGesture {
    var currentViewOffset: Double
    var animation: ViewOffsetAnimation?  // Deceleration animation during gesture
    var tracker: SwipeTracker
    var deltaFromTracker: Double
    var stationaryViewOffset: Double
    var isTouchpad: Bool

    mutating func updateDelta() {
        deltaFromTracker = tracker.position
    }
}

// MARK: - Constants

/// Whether to use 1:1 gesture mapping (no amplification)
/// When true, physical swipe distance matches window movement exactly
let VIEW_GESTURE_USE_1TO1_MAPPING: Bool = true

/// Working area movement for gesture normalization (from niri)
/// Only used if VIEW_GESTURE_USE_1TO1_MAPPING is false
let VIEW_GESTURE_WORKING_AREA_MOVEMENT: Double = 1200.0
