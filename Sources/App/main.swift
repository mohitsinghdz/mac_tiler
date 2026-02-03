import Cocoa
import ApplicationServices

class MacTilerApp: NSObject, NSApplicationDelegate {
    var windowObserver: WindowObserver?
    var layoutEngine: LayoutEngine?
    var animationEngine: AnimationEngine?
    var gestureHandler: GestureHandler?
    var displayLink: CVDisplayLink?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility permissions
        if !checkAccessibilityPermissions() {
            showPermissionOnboarding()
            return
        }

        // Initialize subsystems
        layoutEngine = LayoutEngine()
        animationEngine = AnimationEngine(layoutEngine: layoutEngine!)
        windowObserver = WindowObserver(layoutEngine: layoutEngine!)
        gestureHandler = GestureHandler(layoutEngine: layoutEngine!)

        // Connect gesture handler with scanning mode
        layoutEngine?.setupGestureHandler(gestureHandler!)

        // Start event sources
        windowObserver?.start()
        gestureHandler?.setupGestureMonitoring()
        startDisplayLink()

        print("Mac Tiler started successfully")
    }

    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func showPermissionOnboarding() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Mac Tiler needs Accessibility permissions to manage windows.

        Please grant permission in System Settings > Privacy & Security > Accessibility
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }

        NSApplication.shared.terminate(nil)
    }

    func startDisplayLink() {
        func displayLinkCallback(
            _ displayLink: CVDisplayLink,
            _ inNow: UnsafePointer<CVTimeStamp>,
            _ inOutputTime: UnsafePointer<CVTimeStamp>,
            _ flagsIn: CVOptionFlags,
            _ flagsOut: UnsafeMutablePointer<CVOptionFlags>,
            _ context: UnsafeMutableRawPointer?
        ) -> CVReturn {
            let app = Unmanaged<MacTilerApp>.fromOpaque(context!).takeUnretainedValue()

            DispatchQueue.main.async {
                app.animationEngine?.tick()
                app.layoutEngine?.advanceAnimations()
            }

            return kCVReturnSuccess
        }

        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)

        if let displayLink = displayLink {
            let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, context)
            CVDisplayLinkStart(displayLink)
        }
    }
}

// Entry point
let app = NSApplication.shared
let delegate = MacTilerApp()
app.delegate = delegate
app.run()
