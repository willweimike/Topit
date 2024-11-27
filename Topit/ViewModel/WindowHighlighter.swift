//
//  WindowHighlighter.swift
//  Topit
//
//  Created by apple on 2024/11/26.
//

import SwiftUI

struct CoverView: View {
    var body: some View {
        Color.clear.overlay { Rectangle().stroke(.blue, lineWidth: 5) }
    }
}

struct HighlightMask: View {
    let app: String
    let title: String
    let windowID: Int
    @State var color: Color = .blue
    
    var body: some View {
        color
            .opacity(0.2)
            .cornerRadius(10)
            .help("\(app) - \(title)")
            .onPressGesture {
                if let mask = WindowHighlighter.shared.mask {
                    mask.order(.above, relativeTo: windowID)
                    if let _ = SCManager.updateAvailableContentSync(),
                       let window = SCManager.getWindows().first(where: { $0.windowID == windowID }),
                       !SCManager.pinnedWdinwows.contains(window),
                       let display = SCManager.availableContent?.displays.first(where: { $0.displayID == mask.screen?.displayID }) {
                        mask.close()
                        createNewWindow(display: display, window: window)
                        WindowHighlighter.shared.stopMouseMonitor()
                        return
                    }
                    color = .red
                    withAnimation(.easeInOut(duration: 0.6)) { color = .blue }
                }
            }
    }
}

class WindowHighlighter {
    static let shared = WindowHighlighter()
    var mouseMonitor: Any?
    var mouseMonitorL: Any?
    var targetWindowID: Int?
    var mask: EscPanel?
    
    func registerMouseMonitor() {
        DispatchQueue.main.async {
            tips("Click on the window you want to pin\nor press Esc to cancel.".local, id: "topit.how-to-select.note")
        }
        for screen in NSScreen.screens {
            let cover = EscPanel(contentRect: screen.frame, styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
            cover.contentView = NSHostingView(rootView: CoverView())
            cover.level = .statusBar
            cover.sharingType = .none
            cover.backgroundColor = .clear
            cover.ignoresMouseEvents = true
            cover.isReleasedWhenClosed = false
            cover.collectionBehavior = [.canJoinAllSpaces, .stationary]
            cover.title = "Topit Screen Cover"
            cover.orderFront(self)
        }
        
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in self.updateMask() }
        }
        if mouseMonitorL == nil {
            mouseMonitorL = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
                self.updateMask()
                return event
            }
        }
    }
        
    func stopMouseMonitor() {
        DispatchQueue.main.async {
            for w in NSApp.windows.filter({ $0.title == "Topit Screen Cover" }) { w.close() }
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let monitor = mouseMonitorL {
            NSEvent.removeMonitor(monitor)
            mouseMonitorL = nil
        }
    }
    
    func updateMask() {
        guard let targetWindow = getWindowUnderMouse() else {
            mask?.close()
            targetWindowID = nil
            return
        }
        
        if let windowID = targetWindow["kCGWindowNumber"] as? Int,
           let app = targetWindow["kCGWindowOwnerName"] as? String, app != "Topit",
           let frame = getCGWindowFrame(window: targetWindow), targetWindowID != windowID {
            mask?.close()
            targetWindowID = windowID
            let title = targetWindow["kCGWindowName"] as? String ?? ""
            createMaskWindow(app: app, title: title, frame: frame)
        }
    }
    
    func createMaskWindow(app: String, title: String, frame: CGRect) {
        guard let windowID = targetWindowID else { return }
        mask = EscPanel(contentRect: CGRectTransform(cgRect: frame), styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        let contentView = NSHostingView(rootView: HighlightMask(app: app, title: title, windowID: windowID))
        mask?.contentView = contentView
        mask?.title = "Topit Mask Window"
        mask?.hasShadow = false
        mask?.sharingType = .none
        mask?.backgroundColor = .clear
        mask?.titleVisibility = .hidden
        mask?.isMovableByWindowBackground = false
        mask?.isReleasedWhenClosed = false
        mask?.collectionBehavior = [.canJoinAllSpaces, .transient]
        mask?.setFrame(CGRectTransform(cgRect: frame), display: true)
        mask?.order(.above, relativeTo: windowID)
        mask?.makeKey()
    }
}

extension View {
    func onPressGesture(perform: @escaping () -> Void) -> some View {
        self.gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in
                perform()
            }
        )
    }
}
