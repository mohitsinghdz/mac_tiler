import Foundation
import CoreGraphics

/// Column width configuration
enum ColumnWidth: Equatable {
    case proportion(Double)  // Percentage of screen (0.5 = 50%)
    case fixed(Double)       // Absolute pixels
}

/// Window height configuration
enum WindowHeight: Equatable {
    case auto(weight: Double = 1.0)  // Auto-sized with proportional weight
    case fixed(Double)               // Fixed pixel height
    case preset(Int)                 // Preset height from config
}

/// A column of tiled windows
class Column {
    var tiles: [Window]
    private(set) var activeWindowIdx: Int
    var width: ColumnWidth

    // Per-window metadata
    private var windowHeights: [Window.ID: WindowHeight] = [:]

    init(tiles: [Window] = [], width: ColumnWidth = .proportion(1.0)) {
        self.tiles = tiles
        self.activeWindowIdx = 0
        self.width = width

        // Initialize default heights
        for window in tiles {
            windowHeights[window.id] = .auto()
        }
    }

    // MARK: - Window Management

    func addWindow(_ window: Window, at index: Int? = nil) {
        let idx = index ?? tiles.count
        tiles.insert(window, at: idx)
        windowHeights[window.id] = .auto()

        // Adjust active index if needed
        if idx <= activeWindowIdx {
            activeWindowIdx += 1
        }
    }

    func removeWindow(_ window: Window) -> Bool {
        guard let idx = tiles.firstIndex(of: window) else {
            return false
        }

        tiles.remove(at: idx)
        windowHeights.removeValue(forKey: window.id)

        // Adjust active index
        if idx < activeWindowIdx {
            activeWindowIdx = max(0, activeWindowIdx - 1)
        } else if activeWindowIdx >= tiles.count {
            activeWindowIdx = max(0, tiles.count - 1)
        }

        return true
    }

    // MARK: - Navigation

    func focusUp() -> Window? {
        guard !tiles.isEmpty else { return nil }

        activeWindowIdx = max(0, activeWindowIdx - 1)
        return tiles[activeWindowIdx]
    }

    func focusDown() -> Window? {
        guard !tiles.isEmpty else { return nil }

        activeWindowIdx = min(tiles.count - 1, activeWindowIdx + 1)
        return tiles[activeWindowIdx]
    }

    var activeWindow: Window? {
        guard !tiles.isEmpty, activeWindowIdx < tiles.count else {
            return nil
        }
        return tiles[activeWindowIdx]
    }

    // MARK: - Height Management

    func setWindowHeight(_ window: Window, height: WindowHeight) {
        windowHeights[window.id] = height
    }

    func getWindowHeight(_ window: Window) -> WindowHeight {
        return windowHeights[window.id] ?? .auto()
    }

    var isEmpty: Bool {
        return tiles.isEmpty
    }
}
