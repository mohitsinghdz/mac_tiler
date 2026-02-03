import Foundation
import CoreGraphics
import QuartzCore

/// Main scrollable tiling layout (ported from niri's ScrollingSpace)
class ScrollingSpace {
    private(set) var columns: [Column] = []
    private(set) var activeColumnIdx: Int = 0

    var viewOffset: ViewOffset = .static(0.0)
    var workingArea: CGRect
    var gaps: CGFloat = 0  // No gaps between windows
    var screenMargin: CGFloat = 100

    init(workingArea: CGRect) {
        self.workingArea = workingArea
    }

    // MARK: - View Position

    /// Get current view position considering animation state
    func viewPos() -> Double {
        let now = CACurrentMediaTime()

        switch viewOffset {
        case .static(let offset):
            return offset

        case .animation(let anim):
            return anim.value(at: now)

        case .gesture(let gesture):
            let base = gesture.currentViewOffset + gesture.deltaFromTracker

            if let anim = gesture.animation {
                return base + anim.value(at: now)
            }

            return base
        }
    }

    // MARK: - Window Management

    func addWindow(_ window: Window) {
        // Each window gets its own column by default (niri behavior)
        // Stacking multiple windows in a column only happens when user explicitly moves them
        let defaultWidth = ColumnWidth.proportion(0.8)  // 80% of screen width
        let column = Column(tiles: [window], width: defaultWidth)

        if columns.isEmpty {
            // First window
            columns.append(column)
            activeColumnIdx = 0
        } else {
            // Insert new column after active column
            let insertIdx = activeColumnIdx + 1
            columns.insert(column, at: insertIdx)
            activeColumnIdx = insertIdx
        }

        // Retile entire space
        tileAll(animate: false)
    }

    func removeWindow(_ window: Window) {
        for (idx, column) in columns.enumerated() {
            if column.removeWindow(window) {
                // Remove empty columns
                if column.isEmpty {
                    columns.remove(at: idx)

                    // Adjust active column
                    if idx < activeColumnIdx {
                        activeColumnIdx = max(0, activeColumnIdx - 1)
                    } else if activeColumnIdx >= columns.count {
                        activeColumnIdx = max(0, columns.count - 1)
                    }
                }

                tileAll(animate: true)
                return
            }
        }
    }

    func moveWindowToNewColumn(_ window: Window, direction: Direction) {
        // Find and remove window from current column
        for (idx, column) in columns.enumerated() {
            if let windowIdx = column.tiles.firstIndex(of: window) {
                columns[idx].tiles.remove(at: windowIdx)

                // Remove empty columns
                if columns[idx].tiles.isEmpty {
                    columns.remove(at: idx)
                    if idx < activeColumnIdx {
                        activeColumnIdx = max(0, activeColumnIdx - 1)
                    }
                }
                break
            }
        }

        // Create new column with window
        let defaultWidth = ColumnWidth.proportion(0.8)  // 80% of screen width
        let newColumn = Column(tiles: [window], width: defaultWidth)

        if direction == .right {
            // Insert after active column
            let insertIdx = min(activeColumnIdx + 1, columns.count)
            columns.insert(newColumn, at: insertIdx)
            activeColumnIdx = insertIdx
        } else {
            // Insert before active column
            columns.insert(newColumn, at: activeColumnIdx)
        }

        print("Moved window to new column \(activeColumnIdx)")
        tileAll(animate: true)
    }

    // MARK: - Layout

    func tileAll(animate: Bool = false) {
        // Use applyLayout which properly handles view offset (scrolling position)
        applyLayout(animate: animate)
    }

    func calculateColumnWidth(_ column: Column, totalColumns: Int) -> CGFloat {
        switch column.width {
        case .proportion(let p):
            // Proportion of screen width (not divided by columns)
            return workingArea.width * CGFloat(p)
        case .fixed(let w):
            return w
        }
    }

    func tileColumn(_ column: Column, x: CGFloat, width: CGFloat, animate: Bool) {
        guard !column.tiles.isEmpty else { return }

        var y = workingArea.minY
        let numWindows = column.tiles.count

        // Calculate available height
        let availableHeight = workingArea.height - (gaps * CGFloat(numWindows - 1))

        // Calculate per-window heights
        var heights: [CGFloat] = []
        var totalWeight: Double = 0
        var fixedHeight: CGFloat = 0

        for window in column.tiles {
            let windowHeight = column.getWindowHeight(window)

            switch windowHeight {
            case .auto(let weight):
                totalWeight += weight
                heights.append(0)  // Will calculate later
            case .fixed(let h):
                heights.append(h)
                fixedHeight += h
            case .preset(_):
                // TODO: Implement presets
                heights.append(0)
                totalWeight += 1.0
            }
        }

        // Distribute remaining height proportionally
        let remainingHeight = availableHeight - fixedHeight

        for (idx, window) in column.tiles.enumerated() {
            let windowHeight = column.getWindowHeight(window)

            if case .auto(let weight) = windowHeight {
                heights[idx] = remainingHeight * (weight / totalWeight)
            }

            let frame = CGRect(
                x: x,
                y: y,
                width: width,
                height: heights[idx]
            )

            // Position window (will be handled by WindowController via LayoutEngine)
            LayoutEngine.shared?.windowController.setWindowFrame(window, frame: frame, animate: animate)

            y += heights[idx] + gaps
        }
    }

    // MARK: - Navigation

    func focusLeft() -> Window? {
        guard !columns.isEmpty else { return nil }

        activeColumnIdx = max(0, activeColumnIdx - 1)
        return columns[activeColumnIdx].activeWindow
    }

    func focusRight() -> Window? {
        guard !columns.isEmpty else { return nil }

        activeColumnIdx = min(columns.count - 1, activeColumnIdx + 1)
        return columns[activeColumnIdx].activeWindow
    }

    func focusUp() -> Window? {
        guard activeColumnIdx < columns.count else { return nil }
        return columns[activeColumnIdx].focusUp()
    }

    func focusDown() -> Window? {
        guard activeColumnIdx < columns.count else { return nil }
        return columns[activeColumnIdx].focusDown()
    }

    var activeWindow: Window? {
        guard activeColumnIdx < columns.count else { return nil }
        return columns[activeColumnIdx].activeWindow
    }

    // MARK: - Gesture Handling (ported from niri)

    /// Begin horizontal scroll gesture
    /// Ported from scrolling.rs lines 3019-3056
    func viewOffsetGestureBegin(isTouchpad: Bool) {
        let currentOffset = viewPos()

        viewOffset = .gesture(ViewGesture(
            currentViewOffset: currentOffset,
            animation: nil,
            tracker: SwipeTracker(),
            deltaFromTracker: 0,
            stationaryViewOffset: currentOffset,
            isTouchpad: isTouchpad
        ))
    }

    /// Update horizontal scroll gesture
    /// Ported from scrolling.rs lines 3057-3083
    func viewOffsetGestureUpdate(deltaX: Double, timestamp: TimeInterval) {
        guard case .gesture(var gesture) = viewOffset else {
            return
        }

        // Normalize delta based on input type
        // 1:1 mapping: physical swipe distance matches window movement
        let normFactor: Double
        if VIEW_GESTURE_USE_1TO1_MAPPING {
            normFactor = 1.0
        } else {
            normFactor = gesture.isTouchpad ?
                (workingArea.width / VIEW_GESTURE_WORKING_AREA_MOVEMENT) : 1.0
        }

        let normalizedDelta = -deltaX * normFactor

        gesture.tracker.push(delta: normalizedDelta, timestamp: timestamp)
        gesture.updateDelta()

        viewOffset = .gesture(gesture)
    }

    /// End horizontal scroll gesture with snap-to-column
    /// Snaps to whichever window is currently most centered on screen
    func viewOffsetGestureEnd(cancelled: Bool = false) {
        guard case .gesture(let gesture) = viewOffset else {
            return
        }

        if cancelled {
            // Animate back to starting position with sticky snap (no velocity)
            animateViewOffset(to: gesture.stationaryViewOffset, velocity: 0, sticky: true)
            return
        }

        // Get current position (where the user left it)
        let currentPos = gesture.currentViewOffset + gesture.deltaFromTracker

        // Compute snap points (column boundaries)
        let snapPoints = computeSnapPoints()

        guard !snapPoints.isEmpty else {
            viewOffset = .static(currentPos)
            return
        }

        // Find closest snap point to CURRENT position (not projected)
        // This snaps to whichever window is currently most centered on screen
        let targetPos = snapPoints.min(by: { point1, point2 in
            abs(currentPos - point1) < abs(currentPos - point2)
        }) ?? currentPos

        // Update active column index to match the snapped column
        if let snapIdx = snapPoints.firstIndex(where: { abs($0 - targetPos) < 1.0 }) {
            activeColumnIdx = snapIdx
        }

        // Always use sticky snap for satisfying click-into-place feel
        animateViewOffset(to: targetPos, velocity: 0, sticky: true)
    }

    /// Animate view offset to target position
    /// - Parameters:
    ///   - target: Target position to animate to
    ///   - velocity: Initial velocity (use 0 for sticky snap)
    ///   - sticky: If true, uses stiffer spring for satisfying snap feel
    private func animateViewOffset(to target: Double, velocity: Double, sticky: Bool = false) {
        let from = viewPos()
        let now = CACurrentMediaTime()

        // Use different spring parameters for sticky vs momentum-based snapping
        let params: SpringParams
        if sticky {
            // Stiffer spring with critical damping for satisfying click-into-place
            params = SpringParams(
                dampingRatio: 1.0,    // Critically damped - no overshoot
                stiffness: 1500.0,    // Very stiff for instant snap
                epsilon: 0.001
            )
        } else {
            // Default spring with slight underdamping for natural deceleration
            params = SpringParams(
                dampingRatio: 0.85,   // Slight underdamping for subtle bounce
                stiffness: 1200.0,    // Responsive
                epsilon: 0.001
            )
        }

        let spring = Spring(
            from: from,
            to: target,
            initialVelocity: velocity,
            params: params,
            startTime: now
        )

        viewOffset = .animation(ViewOffsetAnimation(
            spring: spring,
            startTime: now
        ))
    }

    /// Compute snap points for all column boundaries
    /// Centers each column on screen
    private func computeSnapPoints() -> [Double] {
        var points: [Double] = []
        var x: Double = 0

        for column in columns {
            let columnWidth = calculateColumnWidth(column, totalColumns: columns.count)

            // Snap point centers the column on screen
            let centerOffset = (Double(workingArea.width) - Double(columnWidth)) / 2.0
            let snapPoint = x - centerOffset

            points.append(snapPoint)

            x += Double(columnWidth + gaps)
        }

        return points
    }

    // MARK: - Animation Advancement

    func advanceAnimations() {
        let now = CACurrentMediaTime()

        // Advance view offset animation
        switch viewOffset {
        case .animation(let anim):
            if anim.isDone(at: now) {
                viewOffset = .static(anim.spring.to)
            }

        case .gesture(var gesture):
            if let anim = gesture.animation, anim.isDone(at: now) {
                gesture.animation = nil
                viewOffset = .gesture(gesture)
            }

        case .static:
            break
        }
    }

    /// Check if we need to update layout (during gesture or animation)
    func needsLayoutUpdate() -> Bool {
        switch viewOffset {
        case .gesture:
            return true  // Always update during gesture
        case .animation:
            return true  // Always update during animation
        case .static:
            return false
        }
    }
}
