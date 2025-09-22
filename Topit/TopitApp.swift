//
//  TopitApp.swift
//  Topit
//
//  Created by apple on 2024/11/17.
//

import SwiftUI
import Cocoa
import Foundation
import ScreenCaptureKit
import KeyboardShortcuts

let ud = UserDefaults.standard
let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
var singleLayer = false
var axPerm = false
var scPerm = false

@main
struct TopitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
                .background(
                    WindowAccessor(
                        onWindowOpen: { w in
                            if let w = w {
                                w.level = .floating
                                w.titlebarSeparatorStyle = .none
                                guard let nsSplitView = findNSSplitVIew(view: w.contentView),
                                      let controller = nsSplitView.delegate as? NSSplitViewController else { return }
                                controller.splitViewItems.first?.canCollapse = false
                                controller.splitViewItems.first?.minimumThickness = 140
                                controller.splitViewItems.first?.maximumThickness = 140
                                w.orderFront(nil)
                            }
                        })
                )
        }.commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    @AppStorage("showOnDock") private var showOnDock: Bool = true
    @AppStorage("showMenubar") private var showMenubar: Bool = true
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        if showOnDock { NSApp.setActivationPolicy(.regular) }
        if let button = statusBarItem.button {
            button.target = self
            button.image = NSImage(named: "statusIcon")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Pin Window to Top".local, action: #selector(openFromMenuBar), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Unpin All Windows".local, action: #selector(unPinAll), keyEquivalent: "u"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings…".local, action: #selector(settings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Check for Updates…".local, action: #selector(checkForUpdates), keyEquivalent: ""))
        //menu.addItem(NSMenuItem(title: "About Topit".local, action: #selector(about), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Topit".local, action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        statusBarItem.menu = menu
        statusBarItem.isVisible = showMenubar
        
        KeyboardShortcuts.onKeyDown(for: .unpinAll) { self.unPinAll() }
        KeyboardShortcuts.onKeyDown(for: .pinUnpin) {
            if let window = getWindowUnderMouse(),
               let windowID = window["kCGWindowNumber"] as? UInt32 {
                SCManager.updateAvailableContent { content in
                    if let scWindow = SCManager.getWindows().first(where: { $0.windowID == windowID }),
                       let scDisplay = getSCDisplayWithMouse(){
                        DispatchQueue.main.async {
                            let allLayerWindows = NSApp.windows.filter({ $0.title.hasPrefix("Topit Layer") && $0.isVisible})
                            let frameNow = CGRectTransform(cgRect: scWindow.frame)
                            if allLayerWindows.map(\.frame).contains(CGRectTransform(cgRect: scWindow.frame)) {
                                NSApp.windows.first(where: {
                                    $0.frame == frameNow && $0.title == "Topit Layer\(scWindow.windowID)"
                                })?.close()
                            } else {
                                closeMainWindow()
                                createNewWindow(display: scDisplay, window: scWindow)
                            }
                        }
                    }
                }
            }
        }
        
        tips("Topit uses the accessibility permissions\nand screen recording permissions\nto control and capture your windows.".local, id: "topit.how-to-use.note")
        tips("macOS will prevent any notifications from appearing while Topit is running\nIt's not a bug or Topit's fault!".local, id: "topit.no-notifications.note")
        
        scPerm = SCManager.updateAvailableContentSync() != nil
        axPerm = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as NSDictionary)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if showOnDock { _ = applicationShouldHandleReopen(NSApp, hasVisibleWindows: false) }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if NSApp.windows.first(where: { $0.title == "Topit".local })?.isVisible != true {
            axPerm = AXIsProcessTrusted()
            let mainPanel = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            if axPerm && scPerm { mainPanel.level = .floating }
            mainPanel.title = "Topit".local
            mainPanel.titlebarSeparatorStyle = .none
            mainPanel.titlebarAppearsTransparent = true
            mainPanel.isMovableByWindowBackground = true
            mainPanel.toolbarStyle = .unifiedCompact
            let contentView = NSHostingView(rootView: ContentView())
            mainPanel.contentView = contentView
            mainPanel.makeKeyAndOrderFront(self)
            mainPanel.center()
        }
        return true
    }
    
    @objc func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    @objc func unPinAll() {
        DispatchQueue.main.async {
            for layer in NSApp.windows.filter({$0.title.hasPrefix("Topit Layer")}) { layer.close() }
        }
    }
    
    @objc func about() {
        openAboutPanel()
    }
    
    @objc func settings() {
        openSettingPanel()
    }
    
    @objc func openFromMenuBar() {
        _ = applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
    }
}

func closeMainWindow() {
    NSApp.windows.first(where: { $0.title == "Topit".local })?.close()
}

func openAboutPanel() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel()
}

func getMenuBarHeight() -> CGFloat {
    let mouseLocation = NSEvent.mouseLocation
    let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
    if let screen = screen {
        return screen.frame.height - screen.visibleFrame.height - (screen.visibleFrame.origin.y - screen.frame.origin.y) - 1
    }
    return 0.0
}

func tips(_ message: String, title: String? = nil, id: String, switchButton: Bool = false, width: Int? = nil, action: (() -> Void)? = nil) {
    let never = (ud.object(forKey: "neverRemindMe") as? [String]) ?? []
    if !never.contains(id) {
        if switchButton {
            let alert = createAlert(title: title ?? Bundle.main.appName + " Tips".local, message: message, button1: "OK", button2: "Don't remind me again", width: width).runModal()
            if alert == .alertSecondButtonReturn { ud.setValue(never + [id], forKey: "neverRemindMe") }
            if alert == .alertFirstButtonReturn { action?() }
        } else {
            let alert = createAlert(title: title ?? Bundle.main.appName + " Tips".local, message: message, button1: "Don't remind me again", button2: "OK", width: width).runModal()
            if alert == .alertFirstButtonReturn { ud.setValue(never + [id], forKey: "neverRemindMe") }
            if alert == .alertSecondButtonReturn { action?() }
        }
    }
}

func createAlert(level: NSAlert.Style = .warning, title: String, message: String, button1: String, button2: String = "", width: Int? = nil) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = title.local
    alert.informativeText = message.local
    alert.addButton(withTitle: button1.local)
    if button2 != "" { alert.addButton(withTitle: button2.local) }
    alert.alertStyle = level
    if let width = width {
        alert.accessoryView = NSView(frame: NSMakeRect(0, 0, Double(width), 0))
    }
    return alert
}

func openSettingPanel() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.mainMenu?.items.first?.submenu?.item(at: 3)?.performAction()
}

func findNSSplitVIew(view: NSView?) -> NSSplitView? {
    var queue = [NSView]()
    if let root = view { queue.append(root) }
    
    while !queue.isEmpty {
        let current = queue.removeFirst()
        if current is NSSplitView { return current as? NSSplitView }
        for subview in current.subviews { queue.append(subview) }
    }
    return nil
}

extension NSMenuItem {
    func performAction() {
        guard let menu else { return }
        menu.performActionForItem(at: menu.index(of: self))
    }
}

class NNSPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

extension Scene {
    func myWindowIsContentResizable() -> some Scene {
        return self.windowResizability(.contentSize)
    }
}

extension Bundle {
    var appName: String {
        let appName = self.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                     ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
                     ?? "Unknown App Name"
        return appName
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        return deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
    }
    var isMainScreen: Bool {
        guard let id = self.displayID else { return false }
        return (CGDisplayIsMain(id) == 1)
    }
}

extension SCDisplay {
    var nsScreen: NSScreen? {
        return NSScreen.screens.first(where: { $0.displayID == self.displayID })
    }
}

extension String {
    var local: String { return NSLocalizedString(self, comment: "") }
}
