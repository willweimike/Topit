//
//  Accessibility.swift
//  Topit
//
//  Created by apple on 2024/11/18.
//

import SwiftUI
import ScreenCaptureKit

func getScreenWithMouse() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    let screenWithMouse = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
    return screenWithMouse
}

func getSCDisplayWithMouse() -> SCDisplay? {
    if let displays = SCManager.availableContent?.displays {
        for display in displays {
            if let currentDisplayID = getScreenWithMouse()?.displayID {
                if display.displayID == currentDisplayID {
                    return display
                }
            }
        }
    }
    return nil
}

func getAppIcon(_ app: SCRunningApplication) -> NSImage? {
    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 69, height: 69)
        return icon
    }
    let icon = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: "blank icon")
    icon!.size = NSSize(width: 69, height: 69)
    return icon
}

func createNewWindow(display: SCDisplay, window: SCWindow) {
    @AppStorage("hasShadow") var hasShadow: Bool = true
    @AppStorage("fullScreenFloating") var fullScreenFloating: Bool = true
    
    let panel = NNSPanel(contentRect: CGRectTransform(cgRect: window.frame, display: display), styleMask: [.closable, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
    var contentView: NSView!
    if #unavailable(macOS 13) {
        contentView = NSHostingView(rootView: OverlayView12(display: display, window: window))
    } else {
        contentView = NSHostingView(rootView: OverlayView(display: display, window: window))
    }
    panel.contentView = contentView
    panel.title = "Topit Layer\(window.windowID)"
    panel.level = .floating
    panel.hasShadow = hasShadow
    panel.backgroundColor = .clear
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.isReleasedWhenClosed = false
    if fullScreenFloating { panel.collectionBehavior = [.canJoinAllSpaces] }
    panel.makeKeyAndOrderFront(nil)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        panel.setFrame(CGRectTransform(cgRect: window.frame, display: display), display: true)
        if let id = window.owningApplication?.bundleIdentifier {
            NSApp.activate(ignoringOtherApps: true)
            bringAppToFront(bundleIdentifier: id)
        }
    }
}

func getWindowUnderMouse() -> [String: Any]? {
    let mousePosition = NSEvent.mouseLocation

    guard var windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements,.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
        print("Get window list failed!")
        return nil
    }
    
    var appBlackList = [String]()
    if let savedData = ud.data(forKey: "hiddenApps"),
       let decodedApps = try? JSONDecoder().decode([AppInfo].self, from: savedData) {
        appBlackList = (decodedApps as [AppInfo]).map({ $0.displayName })
    }
    appBlackList.append("Topit")
    
    windowList = windowList.filter({
        !["SystemUIServer", "Window Server"].contains($0["kCGWindowOwnerName"] as? String)
        && $0["kCGWindowAlpha"] as? NSNumber != 0
        && $0["kCGWindowLayer"] as? NSNumber == 0
    })
    for window in windowList {
        guard let boundsDict = window["kCGWindowBounds"] as? [String: CGFloat] else { continue }

        let bounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
        
        if CGRectTransform(cgRect: bounds).contains(mousePosition) {
            if appBlackList.contains(window["kCGWindowOwnerName"] as? String ?? "-") { return nil }
            return window
        }
    }

    print("No window under mouse.")
    return nil
}

func CGRectTransform(cgRect: CGRect, display: SCDisplay? = nil) -> NSRect {
    let x = cgRect.origin.x
    let y = cgRect.origin.y
    let w = cgRect.width
    let h = cgRect.height
    if let main = NSScreen.screens.first(where: { $0.isMainScreen }) {
        return NSRect(x: x, y: main.frame.height - y - h, width: w, height: h)
    }
    if let display = display {
        return NSRect(x: x, y: display.frame.height - y - h, width: w, height: h)
    }
    return cgRect
}

func CGPointTransform(cgPoint: CGPoint, mainHeight: CGFloat) -> NSPoint {
    let x = cgPoint.x
    let y = cgPoint.y
    return NSPoint(x: x, y: mainHeight - y)
}

func bringAppToFront(bundleIdentifier: String) {
    if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
        app.activate(options: [.activateIgnoringOtherApps])
    } else {
        print("Application not found.")
    }
}

func isWindowOnTop(windowID: CGWindowID) -> Bool {
    guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenAboveWindow, windowID) as? [[String: Any]] else {
        return false
    }
    return windowList.isEmpty
}

func getCGWindowFrame(windowID: CGWindowID) -> CGRect? {
    guard let cgWindows = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]] else {
        return nil
    }
    if let cgWindow = cgWindows.first {
        if let boundsDict = cgWindow["kCGWindowBounds"] as? [String: CGFloat],
           let x = boundsDict["X"], let y = boundsDict["Y"],
           let width = boundsDict["Width"], let height = boundsDict["Height"] {
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }
    return nil
}

func getApplication(of windowNumber: Int) -> Int? {
    // 获取指定窗口的信息
    guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(windowNumber)) as? [[String: Any]] else {
        return nil
    }
    
    // 获取第一个匹配的窗口信息
    if let windowInfo = windowList.first {
        // 从窗口信息中提取层级
        if let windowLayer = windowInfo[kCGWindowLayer as String] as? Int {
            return windowLayer
        }
    }
    
    return nil
}

func getAXWindow(windowID: CGWindowID) -> AXUIElement? {
    // 获取窗口的基本信息
    guard let cgWindows = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]] else {
        return nil
    }
    guard let cgWindow = cgWindows.first else {
        print("No matching CGWindow found!")
        return nil
    }

    // 获取窗口的进程 ID
    guard let pid = cgWindow["kCGWindowOwnerPID"] as? pid_t else {
        print("Failed to retrieve PID for CGWindow.")
        return nil
    }

    // 创建应用的 AXUIElement
    let appElement = AXUIElementCreateApplication(pid)
    var appWindows: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &appWindows)
    guard result == .success, let windows = appWindows as? [AXUIElement] else {
        print("Failed to retrieve AXUIElement windows for application.")
        return nil
    }

    // 提取 CGWindow 的标题、位置和尺寸
    let cgWindowTitle = cgWindow["kCGWindowName"] as? String
    let cgWindowBounds = cgWindow["kCGWindowBounds"] as? [String: CGFloat]
    let cgWindowX = cgWindowBounds?["X"] ?? 0
    let cgWindowY = cgWindowBounds?["Y"] ?? 0
    let cgWindowWidth = cgWindowBounds?["Width"] ?? 0
    let cgWindowHeight = cgWindowBounds?["Height"] ?? 0
    let cgWindowFrame = CGRect(x: cgWindowX, y: cgWindowY, width: cgWindowWidth, height: cgWindowHeight)

    // 匹配窗口的 AXUIElement
    for axWindow in windows {
        // 检查标题
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &title)
        let axTitle = title as? String

        // 检查位置和尺寸
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        var axPosition = CGPoint.zero
        var axSize = CGSize.zero

        if AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue) == .success {
            let position = positionValue as! AXValue
            AXValueGetValue(position, .cgPoint, &axPosition)
        }

        if AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue) == .success {
            let size = sizeValue as! AXValue
            AXValueGetValue(size, .cgSize, &axSize)
        }

        let axFrame = CGRect(origin: axPosition, size: axSize)

        // 同时匹配标题、位置和尺寸
        if axTitle == cgWindowTitle, axFrame.equalTo(cgWindowFrame) {
            return axWindow
        }
    }

    print("No matching AXUIElement found!")
    return nil
}

func activateWindow(axWindow: AXUIElement?, frame: CGRect) {
    if let axWindow = axWindow {
        var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
        AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, AXValue.from(point: &position))
        
        var size = CGSize(width: frame.width, height: frame.height)
        AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, AXValue.from(size: &size))
        
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
    }
}


func closeAXWindow(_ axWindow: AXUIElement?) -> Bool {
    guard let axWindow = axWindow else { return false }
    
    var closeButtonRef: CFTypeRef?
    let closeButtonResult = AXUIElementCopyAttributeValue(axWindow, kAXCloseButtonAttribute as CFString, &closeButtonRef)
    guard closeButtonResult == .success, let closeButton = closeButtonRef else { return false }
    let closeActionResult = AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
    if closeActionResult == .success { return true }
    print("Failed to close the window!")
    return false
}

// AXValue 扩展，便于设置值
extension AXValue {
    static func from(point: inout CGPoint) -> AXValue {
        return AXValueCreate(.cgPoint, &point)!
    }

    static func from(size: inout CGSize) -> AXValue {
        return AXValueCreate(.cgSize, &size)!
    }
}
