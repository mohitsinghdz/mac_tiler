import Foundation
import CoreGraphics

/// Handles positioning of windows based on view offset and column layout
extension ScrollingSpace {

    /// Apply current layout with view offset (scrolling)
    /// All windows move together as a horizontal strip
    func applyLayout(animate: Bool = true) {
        guard !columns.isEmpty else { return }

        let currentViewOffset = viewPos()
        let numColumns = columns.count

        // Start position: workingArea.minX offset by viewOffset
        // All windows move together based on viewOffset
        var x: Double = Double(workingArea.minX) - currentViewOffset

        for column in columns {
            // Calculate column width
            let columnWidth = calculateColumnWidth(column, totalColumns: numColumns)

            // Position window at x (no constraints during scrolling - all move together)
            tileColumn(column, x: CGFloat(x), width: columnWidth, animate: animate)

            x += Double(columnWidth + gaps)
        }
    }

    /// Calculate the view offset needed to center a specific column
    func viewOffsetToCenter(columnIndex: Int) -> Double {
        guard columnIndex >= 0 && columnIndex < columns.count else { return 0 }

        var x: Double = 0
        for i in 0..<columnIndex {
            let columnWidth = calculateColumnWidth(columns[i], totalColumns: columns.count)
            x += Double(columnWidth + gaps)
        }

        // Calculate offset to center this column
        let columnWidth = calculateColumnWidth(columns[columnIndex], totalColumns: columns.count)
        let centerOffset = (Double(workingArea.width) - Double(columnWidth)) / 2.0

        return x - centerOffset
    }

    /// Center the active column immediately (used when entering scanning mode)
    func centerActiveColumn() {
        let targetOffset = viewOffsetToCenter(columnIndex: activeColumnIdx)
        viewOffset = .static(targetOffset)
    }
}
