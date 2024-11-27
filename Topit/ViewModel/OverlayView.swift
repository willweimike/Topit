//
//  ScreenCaptureView.swift
//  Topit
//
//  Created by apple on 2024/11/23.
//


import SwiftUI
import Foundation
import AVFoundation
import ScreenCaptureKit

struct MenuItem<Content: View>: View {
    var action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering: Bool = false
    
    var body: some View {
        Button(action: action) { content() }
            .buttonStyle(.plain)
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
            .onHover { hover in hovering = hover}
            .foregroundStyle(hovering ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(hovering ? .blue : .clear)
            )
    }
}

struct OverlayView: View {
    var display: SCDisplay!
    var window: SCWindow!
    @State private var timer: Timer?
    @StateObject private var captureManager = ScreenCaptureManager()
    @State private var opacity: Double = 1
    @State private var overButtons: Bool = false
    @State private var overView: Bool = false
    @State private var resizing: Bool = false
    @State private var showPopover: Bool = false
    @State private var nsWindow: NSWindow?
    @State private var nsScreen: NSScreen?
    @State private var axWindow: AXUIElement?
    @State private var windowSize: CGSize = .zero
    
    @State private var capturing: Bool = false
    @State private var pausing: Bool = false
    
    @AppStorage("showCloseButton") private var showCloseButton: Bool = true
    @AppStorage("showUnpinButton") private var showUnpinButton: Bool = true
    @AppStorage("showPauseButton") private var showPauseButton: Bool = true
    @AppStorage("splitButtons") private var splitButtons: Bool = false
    @AppStorage("buttonPosition") private var buttonPosition: Int = 0
    
    var body: some View {
        ZStack(alignment: Alignment(
            horizontal: buttonPosition < 2 ? .leading : .trailing,
            vertical: buttonPosition % 2 == 0 ? .top : .bottom
        )) {
            Group {
                ScreenCaptureView(manager: captureManager)
                    .frame(width: windowSize.width, height: windowSize.height)
                    .background(
                        WindowAccessor(
                            onWindowOpen: { w in
                                nsWindow = w
                                SCManager.pinnedWdinwows.append(window)
                                if nsWindow != nil {
                                    nsWindow?.makeKeyAndOrderFront(self)
                                    checkMouseLocation()
                                }
                            },
                            onWindowClose: {
                                SCManager.pinnedWdinwows.removeAll(where: { $0 === window })
                                timer?.invalidate()
                                nsWindow = nil
                                stopCapture()
                            }
                        )
                    )
            }.opacity(opacity)
            if !resizing {
                Group {
                    if !splitButtons {
                        Button(action: {
                            showPopover.toggle()
                        }, label: {
                            Image("statusIcon")
                                .resizable().scaledToFit()
                                .frame(width: 12, height: 12)
                                .padding(4)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.buttonBlue)
                                )
                        })
                        .buttonStyle(.plain)
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(.secondary.opacity(0.5), lineWidth: 0.5)
                                .padding(0.5)
                        }
                    } else {
                        HStack {
                            if axWindow != nil && showCloseButton {
                                Button(action: {
                                    nsWindow?.close()
                                    _ = closeAXWindow(axWindow)
                                }, label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 7, weight: .black))
                                        .frame(width: 12, height: 12)
                                        .foregroundStyle(overButtons ? .buttonRedDark : .clear)
                                        .background(Circle().fill(.buttonRed))
                                })
                                .buttonStyle(.plain)
                                .help("Close")
                            }
                            if showPauseButton {
                                Button(action: {
                                    pausing.toggle()
                                    if pausing { stopCapture() } else { restartCapture() }
                                }, label: {
                                    Image(systemName: pausing ? "play.fill" : "pause.fill")
                                        .font(.system(size: 8, weight: .medium))
                                        .frame(width: 12, height: 12)
                                        .foregroundStyle(overButtons ? .buttonBlueDark : .clear)
                                        .background(Circle().fill(.buttonBlue))
                                })
                                .buttonStyle(.plain)
                                .help(pausing ? "Resume" :"Unpin")
                            }
                            if showUnpinButton {
                                Button(action: {
                                    nsWindow?.close()
                                }, label: {
                                    Image(systemName: "pin.slash.fill")
                                        .font(.system(size: 7, weight: .black))
                                        .frame(width: 12, height: 12)
                                        .rotationEffect(.degrees(45))
                                        .foregroundStyle(overButtons ? .buttonYellowDark : .clear)
                                        .background(Circle().fill(.buttonYellow))
                                })
                                .buttonStyle(.plain)
                                .help("Unpin")
                            }
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(.blackWhite)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.secondary.opacity(0.5), lineWidth: 0.5)
                                .padding(0.5)
                        }
                    }
                }
                .padding(4)
                .onHover { hovering in
                    overButtons = hovering
                    nsWindow?.makeKeyAndOrderFront(self)
                }
                .popover(isPresented: $showPopover, arrowEdge: buttonPosition % 2 == 0 ? .bottom : .top) {
                    VStack(spacing: 4) {
                        MenuItem(action: {nsWindow?.close()}) {
                            HStack(spacing: 7) {
                                Image(systemName: "pin.circle")
                                Text("Unpin").padding(.trailing, 2)
                            }
                        }
                        Divider().padding(.horizontal, 5)
                        MenuItem(action: {
                            pausing.toggle()
                            if pausing { stopCapture() } else { restartCapture() }
                        }) {
                            HStack(spacing: 7) {
                                Image(systemName: pausing ? "play.circle" : "pause.circle")
                                Text(pausing ? "Resume" : "Pause").padding(.trailing, 2)
                            }
                        }
                        if axWindow != nil {
                            Divider().padding(.horizontal, 5)
                            MenuItem(action: {
                                nsWindow?.close()
                                _ = closeAXWindow(axWindow)
                            }) {
                                HStack(spacing: 7) {
                                    Image(systemName: "xmark.circle")
                                    Text("Close").padding(.trailing, 2)
                                }
                            }
                        }
                    }.padding(6)
                }.focusable(false)
            }
        }
        .onAppear {
            windowSize = window.frame.size
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                //let front = isFrontmostWindow(appID: window.owningApplication?.processID, windowID: window.windowID)
                //if let shadow = nsWindow?.hasShadow { if !front && !shadow { nsWindow?.hasShadow = true }}
                if let frame = getCGWindowFrameWithID(window.windowID) {
                    let newFrame = CGRectTransform(cgRect: frame, display: display)
                    if newFrame != nsWindow?.frame {
                        opacity = 0
                        resizing = true
                        if capturing { stopCapture() }
                        let newDisplay = nsWindow?.screen
                        if newFrame.size != nsWindow?.frame.size || nsScreen != newDisplay {
                            nsScreen = newDisplay
                            captureManager.updateStreamSize(newWidth: frame.width, newHeight: frame.height, screen: newDisplay)
                        }
                        nsWindow?.setFrame(CGRectTransform(cgRect: frame, display: display), display: true)
                        windowSize = frame.size
                    } else {
                        if !overView && !pausing {
                            if !capturing { restartCapture() }
                            opacity = 1
                        }
                        if pausing {
                            if nsWindow?.level != .normal { nsWindow?.level = .normal }
                            nsWindow?.order(.above, relativeTo: Int(window.windowID))
                        }
                        resizing = false
                    }
                } else {
                    if captureManager.capturing { nsWindow?.close() }
                }
            }
            axWindow = getAXWindow(windowID: window.windowID)
            Task {
                await captureManager.startCapture(display: display, window: window)
                self.capturing = true
            }
        }
        .onChange(of: captureManager.capturError) { newValue in if newValue { nsWindow?.close() }}
        .onChange(of: opacity) { newValue in
            //nsWindow?.hasShadow = false
            if newValue == 1 { nsWindow?.hasShadow = true } else { nsWindow?.hasShadow = false }
        }
        .onHover { hovering in
            overView = hovering
            if resizing || pausing { return }
            if hovering {
                nsWindow?.level = .floating
                nsWindow?.makeKeyAndOrderFront(self)
                if let id = window.owningApplication?.bundleIdentifier, let win = nsWindow {
                    activateWindow(axWindow: axWindow, frame: CGRectTransform(cgRect: win.frame, display: display))
                    NSApp.activate(ignoringOtherApps: true)
                    bringAppToFront(bundleIdentifier: id)
                    withAnimation(.easeOut(duration: 0.1)) { opacity = 0 }
                }
                stopCapture()
            } else {
                restartCapture()
                opacity = 1
            }
        }
    }
    
    private func restartCapture() {
        if let frame = nsWindow?.frame {
            Task {
                await captureManager.resumeCapture(newWidth: frame.width, newHeight: frame.height, screen: nsScreen)
                self.capturing = true
            }
        }
    }
    
    private func stopCapture() {
        if !capturing { return }
        capturing = false
        captureManager.stopCapture()
    }
    
    private func checkMouseLocation() {
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = CGRectTransform(cgRect: window.frame)
        let mouseInWindow = windowFrame.contains(NSPoint(x: mouseLocation.x, y: mouseLocation.y))
        if mouseInWindow { opacity = 0 }
    }
}

struct ScreenCaptureView: NSViewRepresentable {
    @ObservedObject var manager: ScreenCaptureManager

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        updateLayer(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        updateLayer(for: nsView)
    }

    private func updateLayer(for view: NSView) {
        guard let layer = view.layer else { return }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let videoLayer = manager.videoLayer
        videoLayer.frame = view.bounds
        videoLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer.addSublayer(videoLayer)
    }
}
