import Foundation
import CoreGraphics

/// Handles positioning of windows based on view offset and column layout
extension ScrollingSpace {

    /// Apply current layout with view offset (scrolling)
    /// All windows move together as a horizontal strip
    /// Windows in active column also respond to vertical offset
    func applyLayout(animate: Bool = true) {
        guard !columns.isEmpty else { return }

        let currentViewOffset = viewPos()
        let currentVerticalOffset = verticalViewPos()
        let numColumns = columns.count

        // Start position: workingArea.minX offset by viewOffset
        // All windows move together based on viewOffset
        var x: Double = Double(workingArea.minX) - currentViewOffset

        for (colIdx, column) in columns.enumerated() {
            // Calculate column width
            let columnWidth = calculateColumnWidth(column, totalColumns: numColumns)

            // Only apply vertical offset to the active column
            let vOffset = (colIdx == activeColumnIdx) ? currentVerticalOffset : 0.0

            // Position window at x with vertical offset
            tileColumn(column, x: CGFloat(x), width: columnWidth, verticalOffset: vOffset, animate: animate)

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
