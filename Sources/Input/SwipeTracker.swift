import Foundation

/// Velocity tracker for swipe gestures (ported from niri/src/input/swipe_tracker.rs)
class SwipeTracker {
    private struct Event {
        let delta: Double
        let timestamp: TimeInterval
    }

    private var history: [Event] = []
    private var pos: Double = 0

    // Constants from niri (swipe_tracker.rs)
    private let historyLimit: TimeInterval = 0.150  // 150ms
    private let deceleration: Double = 0.997        // Touchpad deceleration

    /// Current position
    var position: Double {
        return pos
    }

    /// Push a new delta event
    func push(delta: Double, timestamp: TimeInterval) {
        history.append(Event(delta: delta, timestamp: timestamp))
        pos += delta
        trimHistory(currentTime: timestamp)
    }

    /// Calculate current velocity from event history
    func velocity() -> Double {
        guard let first = history.first,
              let last = history.last else {
            return 0
        }

        let totalTime = last.timestamp - first.timestamp
        guard totalTime > 0 else { return 0 }

        let totalDelta = history.reduce(0.0) { $0 + $1.delta }
        return totalDelta / totalTime
    }

    /// Project where the gesture would end based on current velocity
    /// Uses deceleration curve to predict final position
    func projectedEndPos() -> Double {
        let vel = velocity()
        // Formula: pos = vel / (1000 * ln(decel))
        // Derived from exponential deceleration: v(t) = v0 * decel^t
        return pos - vel / (1000.0 * log(deceleration))
    }

    /// Reset tracker state
    func reset() {
        history.removeAll()
        pos = 0
    }

    // MARK: - Private

    private func trimHistory(currentTime: TimeInterval) {
        // Keep only events within history limit
        history.removeAll { event in
            currentTime - event.timestamp > historyLimit
        }
    }
}
