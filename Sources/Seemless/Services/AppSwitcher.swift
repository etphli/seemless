import AppKit
import ApplicationServices

struct WindowTarget: Identifiable {
    let id: Int
    let title: String
    let element: AXUIElement
    let app: NSRunningApplication
}

struct FocusTarget {
    let app: NSRunningApplication
    let window: AXUIElement?
}

@MainActor
final class AppSwitcher {
    private var returnTargets: [String: FocusTarget] = [:]
    private var lastWindows: [String: AXUIElement] = [:]
    private(set) var lastExternalApp: NSRunningApplication?

    var hasAccessibility: Bool { AXIsProcessTrusted() }

    func capture() -> FocusTarget? {
        let active = NSWorkspace.shared.frontmostApplication
        let app = active?.bundleIdentifier == Bundle.main.bundleIdentifier ? lastExternalApp : active
        guard let app else { return nil }
        lastExternalApp = app
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.2)
        let window = hasAccessibility ? Self.elementAttribute(element, kAXFocusedWindowAttribute) : nil
        if let window, let id = app.bundleIdentifier { lastWindows[id] = window }
        return FocusTarget(app: app, window: window)
    }

    func switchTo(_ app: InstalledApp, origin: FocusTarget?, onError: @escaping (String) -> Void) {
        if origin?.app.bundleIdentifier == app.bundleID, let previous = returnTargets[app.bundleID], !previous.app.isTerminated {
            focus(previous)
            return
        }
        if let origin { returnTargets[app.bundleID] = origin }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).first {
            focus(FocusTarget(app: running, window: lastWindows[app.bundleID]))
        } else {
            NSWorkspace.shared.openApplication(at: app.url, configuration: .init()) { _, error in
                if let error { Task { @MainActor in onError("Could not open \(app.name): \(error.localizedDescription)") } }
            }
        }
    }

    func focus(_ target: FocusTarget) {
        guard !target.app.isTerminated else { return }
        if NSApp.isActive { NSApp.yieldActivation(to: target.app) }
        target.app.activate(options: [])
        if hasAccessibility, let window = target.window {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(AXUIElementCreateApplication(target.app.processIdentifier), kAXFocusedWindowAttribute as CFString, window)
        }
    }

    func windows(in app: NSRunningApplication?) -> [WindowTarget] {
        guard hasAccessibility, let app else { return [] }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows.enumerated().compactMap { index, window in
            var titleValue: CFTypeRef?
            AXUIElementSetMessagingTimeout(window, 0.2)
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            let title = titleValue as? String ?? ""
            guard !title.isEmpty else { return nil }
            return WindowTarget(id: index, title: title, element: window, app: app)
        }
    }

    static func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
}
