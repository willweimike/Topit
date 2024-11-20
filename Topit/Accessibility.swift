//
//  Accessibility.swift
//  Topit
//
//  Created by apple on 2024/11/18.
//

import Foundation
import ScreenCaptureKit
import Cocoa

func cg2ns(cgRect: CGRect, display: SCDisplay) -> NSRect {
    let x = cgRect.origin.x
    let y = cgRect.origin.y
    let w = cgRect.width
    let h = cgRect.height
    if let main = NSScreen.screens.first(where: { $0.isMainScreen }) {
        return NSRect(x: x, y: main.frame.height - y - h, width: w, height: h)
    }
    return NSRect(x: x, y: display.frame.height - y - h, width: w, height: h)
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

// AXValue 扩展，便于设置值
extension AXValue {
    static func from(point: inout CGPoint) -> AXValue {
        return AXValueCreate(.cgPoint, &point)!
    }

    static func from(size: inout CGSize) -> AXValue {
        return AXValueCreate(.cgSize, &size)!
    }
}
