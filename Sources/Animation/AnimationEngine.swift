import Foundation
import CoreGraphics
import QuartzCore

/// Animation engine with CADisplayLink for 120Hz updates
class AnimationEngine {
    private weak var layoutEngine: LayoutEngine?
    private var activeAnimations: [WindowSpringAnimation] = []

    /// Spring-based window animation for smooth, natural motion
    struct WindowSpringAnimation {
        let window: Window
        let xSpring: Spring
        let ySpring: Spring
        let wSpring: Spring
        let hSpring: Spring

        /// Check if all springs have settled
        func isDone(at time: TimeInterval) -> Bool {
            return xSpring.isDone(time) &&
                   ySpring.isDone(time) &&
                   wSpring.isDone(time) &&
                   hSpring.isDone(time)
        }

        /// Get current frame from springs
        func frame(at time: TimeInterval) -> CGRect {
            return CGRect(
                x: xSpring.valueAt(time),
                y: ySpring.valueAt(time),
                width: wSpring.valueAt(time),
                height: hSpring.valueAt(time)
            )
        }

        /// Get target frame
        var targetFrame: CGRect {
            return CGRect(
                x: xSpring.to,
                y: ySpring.to,
                width: wSpring.to,
                height: hSpring.to
            )
        }
    }

    /// Spring parameters optimized for window animations
    /// Slightly underdamped for a satisfying bounce effect
    static let windowSpringParams = SpringParams(
        dampingRatio: 0.85,  // Slightly underdamped for subtle bounce
        stiffness: 600.0,    // Responsive but not jarring
        epsilon: 0.5         // Pixel-level precision for frames
    )

    init(layoutEngine: LayoutEngine) {
        self.layoutEngine = layoutEngine
    }

    /// Called every frame (up to 120Hz on ProMotion)
    func tick() {
        let now = CACurrentMediaTime()
        var remaining: [WindowSpringAnimation] = []

        for anim in activeAnimations {
            // Get current frame from springs
            let frame = anim.frame(at: now)

            // Apply to window
            layoutEngine?.windowController.setWindowFrame(anim.window, frame: frame, animate: false)

            // Keep if not done
            if !anim.isDone(at: now) {
                remaining.append(anim)
            } else {
                // Ensure final position is exact
                layoutEngine?.windowController.setWindowFrame(anim.window, frame: anim.targetFrame, animate: false)
            }
        }

        activeAnimations = remaining
    }

    /// Animate window to target frame using spring physics
    func animate(window: Window, toFrame: CGRect, initialVelocity: CGPoint = .zero) {
        let currentFrame = window.currentFrame
        let now = CACurrentMediaTime()
        let params = Self.windowSpringParams

        // Remove any existing animation for this window
        activeAnimations.removeAll { $0.window.id == window.id }

        let animation = WindowSpringAnimation(
            window: window,
            xSpring: Spring(
                from: Double(currentFrame.minX),
                to: Double(toFrame.minX),
                initialVelocity: Double(initialVelocity.x),
                params: params,
                startTime: now
            ),
            ySpring: Spring(
                from: Double(currentFrame.minY),
                to: Double(toFrame.minY),
                initialVelocity: Double(initialVelocity.y),
                params: params,
                startTime: now
            ),
            wSpring: Spring(
                from: Double(currentFrame.width),
                to: Double(toFrame.width),
                initialVelocity: 0,
                params: params,
                startTime: now
            ),
            hSpring: Spring(
                from: Double(currentFrame.height),
                to: Double(toFrame.height),
                initialVelocity: 0,
                params: params,
                startTime: now
            )
        )

        activeAnimations.append(animation)
    }

    /// Check if any animations are active
    var hasActiveAnimations: Bool {
        return !activeAnimations.isEmpty
    }

    /// Cancel all animations for a window
    func cancelAnimations(for window: Window) {
        activeAnimations.removeAll { $0.window.id == window.id }
    }
}
