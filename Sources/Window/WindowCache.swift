import Foundation
import CoreGraphics
import QuartzCore

/// Cache window frames to avoid unnecessary AX calls
class WindowCache {
    static let shared = WindowCache()

    private var frameCache: [Window.ID: CGRect] = [:]
    private var lastUpdateTime: [Window.ID: TimeInterval] = [:]
    private let cacheQueue = DispatchQueue(label: "com.nirimacos.windowcache")

    /// Minimum interval between position updates (in seconds)
    /// 8ms = ~120fps for smoother updates on ProMotion displays
    private let minUpdateInterval: TimeInterval = 0.008

    /// Position threshold - only update if moved more than this many pixels
    /// Lower = smoother but more CPU, higher = choppier but less CPU
    private let positionThreshold: CGFloat = 0.5

    /// Size threshold - only update if size changed more than this
    private let sizeThreshold: CGFloat = 1.0

    /// Check if window frame needs updating
    func shouldUpdateFrame(_ window: Window, to newFrame: CGRect) -> Bool {
        let now = CACurrentMediaTime()

        return cacheQueue.sync {
            // Check rate limiting
            if let lastUpdate = lastUpdateTime[window.id] {
                if now - lastUpdate < minUpdateInterval {
                    return false  // Too soon, skip this update
                }
            }

            guard let cached = frameCache[window.id] else {
                // Never positioned before
                return true
            }

            // Only update if position changed significantly
            let deltaX = abs(cached.minX - newFrame.minX)
            let deltaY = abs(cached.minY - newFrame.minY)
            let deltaW = abs(cached.width - newFrame.width)
            let deltaH = abs(cached.height - newFrame.height)

            let positionChanged = deltaX > positionThreshold || deltaY > positionThreshold
            let sizeChanged = deltaW > sizeThreshold || deltaH > sizeThreshold

            return positionChanged || sizeChanged
        }
    }

    /// Check if only position changed (size is same)
    func onlyPositionChanged(_ window: Window, to newFrame: CGRect) -> Bool {
        return cacheQueue.sync {
            guard let cached = frameCache[window.id] else {
                return false
            }

            let deltaW = abs(cached.width - newFrame.width)
            let deltaH = abs(cached.height - newFrame.height)

            return deltaW <= sizeThreshold && deltaH <= sizeThreshold
        }
    }

    /// Update cached frame
    func updateFrame(_ window: Window, frame: CGRect) {
        let now = CACurrentMediaTime()
        cacheQueue.async {
            self.frameCache[window.id] = frame
            self.lastUpdateTime[window.id] = now
        }
    }

    /// Clear cache for window
    func clearFrame(_ window: Window) {
        cacheQueue.async {
            self.frameCache.removeValue(forKey: window.id)
            self.lastUpdateTime.removeValue(forKey: window.id)
        }
    }

    /// Clear all cache
    func clearAll() {
        cacheQueue.async {
            self.frameCache.removeAll()
            self.lastUpdateTime.removeAll()
        }
    }
}
