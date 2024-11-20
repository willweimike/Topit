//
//  ContentView.swift
//  Topit
//
//  Created by apple on 2024/11/17.
//

import SwiftUI
import Foundation
import AVFoundation
import ScreenCaptureKit

struct ScreenCaptureView: NSViewRepresentable {
    @ObservedObject var manager: ScreenCaptureManager

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let videoLayer = manager.videoLayer
        videoLayer.videoGravity = .resizeAspectFill
        videoLayer.frame = view.bounds
        videoLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = CALayer()
        view.layer?.addSublayer(videoLayer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct TopView: View {
    var display: SCDisplay!
    var window: SCWindow!
    @State private var timer: Timer?
    @StateObject private var captureManager = ScreenCaptureManager()
    @State private var opacity: Double = 1
    @State private var overClose: Bool = false
    @State private var overView: Bool = false
    @State private var resizing: Bool = false
    @State private var nsWindow: NSWindow?
    @State private var nsScreen: NSScreen?
    @State private var axWindow: AXUIElement?
    @State private var windowSize: CGSize = .zero
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
            Group {
                ScreenCaptureView(manager: captureManager)
                    .frame(width: windowSize.width, height: windowSize.height)
                    .background(
                        WindowAccessor(
                            onWindowOpen: { w in
                                nsWindow = w
                                nsWindow?.makeKeyAndOrderFront(self)
                                checkMouseLocation()
                            },
                            onWindowClose: {
                                timer?.invalidate()
                                nsWindow = nil
                                captureManager.stopCapture()
                            }
                        )
                    )
            }.opacity(opacity)
            if !resizing {
                Button(action: {
                    nsWindow?.close()
                }, label: {
                    Image(systemName: "pin.slash.fill")
                        .font(.subheadline)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                        .background(Circle().fill(overClose ? .buttonRed : .red))
                })
                .padding(4)
                .buttonStyle(.plain)
                .onHover { hovering in
                    overClose = hovering
                    nsWindow?.makeKeyAndOrderFront(self)
                }
            }
        }
        .onAppear {
            windowSize = window.frame.size
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                if let frame = getCGWindowFrame(windowID: window.windowID) {
                    let newFrame = cg2ns(cgRect: frame, display: display)
                    if newFrame != nsWindow?.frame {
                        opacity = 0
                        resizing = true
                        let newDisplay = nsWindow?.screen
                        if newFrame.size != nsWindow?.frame.size || nsScreen != newDisplay {
                            nsScreen = newDisplay
                            captureManager.updateStreamSize(newWidth: frame.width, newHeight: frame.height, screen: newDisplay)
                        }
                        nsWindow?.setFrame(cg2ns(cgRect: frame, display: display), display: true)
                        windowSize = frame.size
                    } else {
                        if !overView { opacity = 1 }
                        resizing = false
                    }
                }
            }
            axWindow = getAXWindow(windowID: window.windowID)
            Task { await captureManager.startCapture(display: display, window: window) }
        }
        .onChange(of: captureManager.capturing) { newValue in if !newValue { nsWindow?.close() }}
        .onChange(of: opacity) { newValue in
            if newValue == 1 { nsWindow?.hasShadow = true } else { nsWindow?.hasShadow = false }
        }
        .onHover { hovering in
            overView = hovering
            if resizing { return }
            if hovering {
                nsWindow?.makeKeyAndOrderFront(self)
                if let id = window.owningApplication?.bundleIdentifier, let win = nsWindow {
                    activateWindow(axWindow: axWindow, frame: cg2ns(cgRect: win.frame, display: display))
                    NSApp.activate(ignoringOtherApps: true)
                    bringAppToFront(bundleIdentifier: id)
                    withAnimation(.easeOut(duration: 0.1)) { opacity = 0  }
                }
            } else {
                opacity = 1
            }
        }
    }
    
    private func checkMouseLocation() {
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        let mouseInWindow = windowFrame.contains(NSPoint(x: mouseLocation.x, y: mouseLocation.y))
        if mouseInWindow { opacity = 0 }
    }
}

struct WinSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var viewModel = WindowSelectorViewModel()
    @State private var selected = [SCWindow]()
    @State private var display: SCDisplay!
    @State private var selectedTab = 0
    @State private var sheeting: Bool = false
    @State private var needRefesh: Bool = true
    @State private var panel: NSWindow?
    //var appDelegate = AppDelegate.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            let allApps = viewModel.windowThumbnails.sorted(by: { $0.key.displayID < $1.key.displayID })
            ForEach(allApps, id: \.key) { element in
                let (screen, thumbnails) = element
                let index = allApps.firstIndex(where: { $0.key == screen }) ?? 0
                ScrollView(showsIndicators:false) {
                    VStack(spacing: 10) {
                        ForEach(0..<thumbnails.count/4 + 1, id: \.self) { rowIndex in
                            HStack(spacing: 16) {
                                ForEach(0..<4, id: \.self) { columnIndex in
                                    let index = 4 * rowIndex + columnIndex
                                    if index <= thumbnails.count - 1 {
                                        let item = thumbnails[index]
                                        Button(action: {
                                            if !selected.contains(item.window) {
                                                selected = [item.window]
                                            } else {
                                                selected.removeAll()
                                            }
                                        }, label: {
                                            VStack(spacing: 1){
                                                ZStack{
                                                    if colorScheme == .light {
                                                        Image(nsImage: item.image)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .colorMultiply(.black)
                                                            .blur(radius: 0.5)
                                                            .opacity(1)
                                                            .frame(width: 160, height: 90, alignment: .center)
                                                    } else {
                                                        Image(nsImage: item.image)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .colorMultiply(.black)
                                                            .colorInvert()
                                                            .blur(radius: 0.5)
                                                            .opacity(1)
                                                            .frame(width: 160, height: 90, alignment: .center)
                                                    }
                                                    Image(nsImage: item.image)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 160, height: 90, alignment: .center)
                                                    Image(systemName: "circle.fill")
                                                        .font(.system(size: 31))
                                                        .foregroundStyle(.white)
                                                        .opacity(selected.contains(item.window) ? 1.0 : 0.0)
                                                        .offset(x: 55, y: 25)
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 27))
                                                        .foregroundStyle(.green)
                                                        .opacity(selected.contains(item.window) ? 1.0 : 0.0)
                                                        .offset(x: 55, y: 25)
                                                    Image(nsImage: getAppIcon(item.window.owningApplication!)!)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 40, height: 40, alignment: .center)
                                                        .offset(y: 35)
                                                }
                                                .padding(5)
                                                .padding([.top, .bottom], 5)
                                                .background(
                                                    Rectangle()
                                                        .foregroundStyle(.blue)
                                                        .cornerRadius(5)
                                                        .opacity(selected.contains(item.window) ? 0.2 : 0.0001)
                                                )
                                                Text(item.window.title!)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                    .frame(width: 160)
                                            }
                                        }).buttonStyle(.plain)
                                    }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .tag(index)
                .tabItem { Text(screen.nsScreen?.localizedName ?? ("Display ".local + "\(index)")) }
                .onAppear { display = screen }
            }
        }
        .focusable(false)
        .frame(width: 728, height: 500)
        .padding([.horizontal, .bottom], 10)
        .padding(.top, 0.5)
        .onChange(of: selectedTab) { _ in selected.removeAll() }
        .background(
            WindowAccessor(
                onWindowOpen: { w in panel = w },
                onWindowActive: { _ in
                    if #unavailable(macOS 14) {
                        if needRefesh {
                            viewModel.setupStreams()
                            selected.removeAll()
                        }
                        needRefesh = false
                    }},
                onWindowClose: { needRefesh = true })
        )
        .onReceive(viewModel.$isReady) { isReady in
            if isReady {
                let allApps = viewModel.windowThumbnails.sorted(by: { $0.key.displayID < $1.key.displayID })
                if let s = NSApp.windows.first(where: { $0.title == "Topit".local })?.screen,
                   let index = allApps.firstIndex(where: { $0.key.displayID == s.displayID }) {
                    selectedTab = index
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    sheeting = true
                }, label: {
                    Image(systemName: "gear").fontWeight(.medium)
                }).sheet(isPresented: $sheeting) { SettingsView(fromPanel: true) }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    viewModel.setupStreams()
                    selected.removeAll()
                }, label: {
                    Image(systemName: "arrow.triangle.2.circlepath").fontWeight(.medium)
                })
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    if let window = selected.first {
                        createNewWindow(display: display, window: window)
                        panel?.close()
                    }
                }, label: {
                    Text(" Topit! ")
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .foregroundStyle(.white)
                        .background(selected.isEmpty ? Color.secondary.opacity(0.5) : .blue)
                        .cornerRadius(5)
                })
                .buttonStyle(.plain)
                .disabled(selected.isEmpty)
                .padding(.leading, 3)
            }
        }
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
        let panel = NNSPanel(contentRect: cg2ns(cgRect: window.frame, display: display), styleMask: [.closable, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        let contentView = NSHostingView(rootView: TopView(display: display, window: window))
        panel.contentView = contentView
        panel.title = window.title ?? "Topit Layer"
        panel.level = .floating
        //panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.makeKeyAndOrderFront(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            panel.setFrame(cg2ns(cgRect: window.frame, display: display), display: true)
            if let id = window.owningApplication?.bundleIdentifier {
                NSApp.activate(ignoringOtherApps: true)
                bringAppToFront(bundleIdentifier: id)
            }
        }
    }
}
