import Foundation
import CoreGraphics

/// Handles positioning of windows based on view offset and column layout
extension ScrollingSpace {

    /// Apply current layout with view offset (scrolling)
    func applyLayout(animate: Bool = true) {
        guard !columns.isEmpty else { return }

        let viewOffset = viewPos()
        let numColumns = columns.count
        var x: Double = -viewOffset  // Apply scroll offset

        for column in columns {
            // Calculate column width
            let columnWidth = calculateColumnWidth(column, totalColumns: numColumns)

            // Constrain to screen bounds with margin
            let constrainedX = constrainColumnX(x: x, width: Double(columnWidth))

            // Tile windows within column at constrained position
            tileColumn(column, x: CGFloat(constrainedX), width: columnWidth, animate: animate)

            x += Double(columnWidth + gaps)
        }
    }

    /// Constrain column X position to keep it partially visible
    /// Only applies if column would go fully off-screen
    private func constrainColumnX(x: Double, width: Double) -> Double {
        let screenLeft = Double(workingArea.minX)
        let screenRight = Double(workingArea.maxX)

        // Calculate column boundaries
        let columnLeft = x
        let columnRight = x + width

        // If fully off left edge, clamp to show screenMargin pixels
        if columnRight < screenLeft {
            return screenLeft - width + Double(screenMargin)
        }

        // If fully off right edge, clamp to show screenMargin pixels
        if columnLeft > screenRight {
            return screenRight - Double(screenMargin)
        }

        // Column is at least partially visible, don't constrain
        return x
    }
}
