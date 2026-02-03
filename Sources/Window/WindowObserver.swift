import Cocoa
import ApplicationServices

/// Observes window creation, destruction, and changes via Accessibility API
class WindowObserver {
    private weak var layoutEngine: LayoutEngine?
    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceObserver: NSObjectProtocol?

    init(layoutEngine: LayoutEngine) {
        self.layoutEngine = layoutEngine
    }

    func start() {
        // Monitor app launches
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.registerApplication(app)
            }
        }

        // Monitor app terminations
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.unregisterApplication(app)
            }
        }

        // Setup observers for existing apps
        for app in NSWorkspace.shared.runningApplications {
            registerApplication(app)
        }

        print("WindowObserver started, monitoring \(observers.count) applications")
    }

    func registerApplication(_ app: NSRunningApplication) {
        // Skip non-regular apps (menu bar items, background processes)
        guard app.activationPolicy == .regular else { return }

        let pid = app.processIdentifier

        // Skip if already observing
        guard observers[pid] == nil else { return }

        var observer: AXObserver?
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let result = AXObserverCreate(pid, { observer, element, notification, refcon in
            let windowObserver = Unmanaged<WindowObserver>.fromOpaque(refcon!).takeUnretainedValue()

            DispatchQueue.main.async {
                windowObserver.handleNotification(
                    element: element,
                    notification: notification as String,
                    app: windowObserver.getApp(for: observer)
                )
            }

        }, &observer)

        guard result == .success, let observer = observer else {
            return
        }

        let axApp = AXUIElementCreateApplication(pid)

        // Add notifications
        let notifications = [
            kAXWindowCreatedNotification,
            kAXUIElementDestroyedNotification,
            kAXFocusedWindowChangedNotification,
            kAXWindowMovedNotification,
            kAXWindowResizedNotification
        ]

        for notification in notifications {
            AXObserverAddNotification(
                observer,
                axApp,
                notification as CFString,
                context
            )
        }

        // Start observing
        CFRunLoopAddSource(
            RunLoop.main.getCFRunLoop(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        observers[pid] = observer

        // Add existing windows
        addExistingWindows(for: app, axApp: axApp)
    }

    func unregisterApplication(_ app: NSRunningApplication) {
        let pid = app.processIdentifier

        if let observer = observers.removeValue(forKey: pid) {
            // Remove from run loop
            CFRunLoopRemoveSource(
                RunLoop.main.getCFRunLoop(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
    }

    private func addExistingWindows(for app: NSRunningApplication, axApp: AXUIElement) {
        var windowListRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            axApp,
            kAXWindowsAttribute as CFString,
            &windowListRef
        )

        guard result == .success,
              let windowList = windowListRef as? [AXUIElement] else {
            return
        }

        for axWindow in windowList {
            let window = Window(axElement: axWindow, app: app)

            if window.isMaximizable() {
                layoutEngine?.addWindow(window)
            }
        }
    }

    private func handleNotification(element: AXUIElement, notification: String, app: NSRunningApplication?) {
        guard let app = app else { return }

        switch notification {
        case kAXWindowCreatedNotification:
            let window = Window(axElement: element, app: app)

            if window.isMaximizable() {
                layoutEngine?.addWindow(window)
            }

        case kAXUIElementDestroyedNotification:
            let window = Window(axElement: element, app: app)
            layoutEngine?.removeWindow(window)

        case kAXFocusedWindowChangedNotification:
            let window = Window(axElement: element, app: app)
            layoutEngine?.focusWindow(window)

        case kAXWindowMovedNotification,
             kAXWindowResizedNotification:
            // Window moved/resized externally - update cache
            let window = Window(axElement: element, app: app)
            window.invalidateCache()

        default:
            break
        }
    }

    private func getApp(for observer: AXObserver) -> NSRunningApplication? {
        // Find app by observer
        for (pid, obs) in observers {
            if obs === observer {
                return NSRunningApplication(processIdentifier: pid)
            }
        }
        return nil
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
