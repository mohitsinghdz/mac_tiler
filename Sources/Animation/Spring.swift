import Foundation

/// Spring physics parameters (ported from niri/src/animation/spring.rs)
struct SpringParams {
    let damping: Double
    let mass: Double
    let stiffness: Double
    let epsilon: Double

    /// Create spring parameters from damping ratio and stiffness
    /// - Parameters:
    ///   - dampingRatio: Damping ratio (1.0 = critically damped)
    ///   - stiffness: Spring stiffness (higher = faster response)
    ///   - epsilon: Convergence threshold
    init(dampingRatio: Double, stiffness: Double, epsilon: Double) {
        let mass = 1.0
        let criticalDamping = 2.0 * sqrt(mass * stiffness)

        self.damping = dampingRatio * criticalDamping
        self.mass = mass
        self.stiffness = max(0, stiffness)
        self.epsilon = max(0, epsilon)
    }

    /// Default spring parameters matching niri's config
    static let `default` = SpringParams(
        dampingRatio: 1.0,
        stiffness: 800.0,
        epsilon: 0.0001
    )
}

/// Spring animation (ported from niri/src/animation/spring.rs)
struct Spring {
    let from: Double
    let to: Double
    let initialVelocity: Double
    let params: SpringParams
    let startTime: TimeInterval

    /// Get spring value at a given time
    func valueAt(_ currentTime: TimeInterval) -> Double {
        let t = currentTime - startTime
        return oscillate(t)
    }

    /// Get spring velocity at a given time
    func velocityAt(_ currentTime: TimeInterval) -> Double {
        let t = currentTime - startTime
        let dt = 0.001  // Small delta for numerical derivative

        let v1 = oscillate(t)
        let v2 = oscillate(t + dt)

        return (v2 - v1) / dt
    }

    /// Check if spring has settled
    func isDone(_ currentTime: TimeInterval) -> Bool {
        let current = valueAt(currentTime)
        let velocity = abs(velocityAt(currentTime))

        return abs(current - to) < params.epsilon && velocity < params.epsilon
    }

    // MARK: - Private

    /// Spring oscillation equation (ported from spring.rs lines 140-180)
    private func oscillate(_ t: Double) -> Double {
        let b = params.damping
        let m = params.mass
        let k = params.stiffness
        let v0 = initialVelocity

        let beta = b / (2.0 * m)
        let omega0 = sqrt(k / m)
        let x0 = from - to
        let envelope = exp(-beta * t)

        // Three cases based on damping

        // Critically damped (no oscillation)
        if abs(beta - omega0) <= Double.ulpOfOne {
            return to + envelope * (x0 + (beta * x0 + v0) * t)
        }
        // Underdamped (oscillates slightly)
        else if beta < omega0 {
            let omega1 = sqrt((omega0 * omega0) - (beta * beta))
            return to + envelope * (
                x0 * cos(omega1 * t) +
                ((beta * x0 + v0) / omega1) * sin(omega1 * t)
            )
        }
        // Overdamped (slow approach)
        else {
            let omega2 = sqrt((beta * beta) - (omega0 * omega0))
            return to + envelope * (
                x0 * cosh(omega2 * t) +
                ((beta * x0 + v0) / omega2) * sinh(omega2 * t)
            )
        }
    }
}

// MARK: - Animation Protocol

/// Animation that can be advanced frame-by-frame
protocol Animation {
    /// Get current value
    func valueAt(_ currentTime: TimeInterval) -> Double

    /// Get current velocity
    func velocityAt(_ currentTime: TimeInterval) -> Double

    /// Check if animation is complete
    func isDone(_ currentTime: TimeInterval) -> Bool

    /// Target value
    var to: Double { get }
}

extension Spring: Animation {}
