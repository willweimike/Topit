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

struct OverlayView: View {
    var display: SCDisplay!
    var window: SCWindow!
    @State private var timer: Timer?
    @StateObject private var captureManager = ScreenCaptureManager()
    @State private var opacity: Double = 1
    @State private var overButtons: Bool = false
    @State private var overView: Bool = false
    @State private var resizing: Bool = false
    @State private var nsWindow: NSWindow?
    @State private var nsScreen: NSScreen?
    @State private var axWindow: AXUIElement?
    @State private var windowSize: CGSize = .zero
    
    @AppStorage("showCloseButton") private var showCloseButton: Bool = true
    @AppStorage("showUnpinButton") private var showUnpinButton: Bool = true
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
            Group {
                ScreenCaptureView(manager: captureManager)
                    .frame(width: windowSize.width, height: windowSize.height)
                    .background(
                        WindowAccessor(
                            onWindowOpen: { w in
                                nsWindow = w
                                if nsWindow != nil {
                                    nsWindow?.makeKeyAndOrderFront(self)
                                    checkMouseLocation()
                                }
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
                HStack {
                    if axWindow != nil && showCloseButton {
                        Button(action: {
                            nsWindow?.close()
                            _ = closeAXWindow(axWindow)
                        }, label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                                .frame(width: 12, height: 12)
                                .foregroundStyle(overButtons ? .buttonRedDark : .clear)
                                .background(Circle().fill(.buttonRed))
                        })
                        .buttonStyle(.plain)
                        .help("Close")
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
                .focusable(false)
                .onHover { hovering in
                    overButtons = hovering
                    nsWindow?.makeKeyAndOrderFront(self)
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.blackWhite)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(.secondary.opacity(0.5), lineWidth: 1)
                        .padding(0.5)
                }
                .padding(4)
            }
        }
        .onAppear {
            windowSize = window.frame.size
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                if let frame = getCGWindowFrame(windowID: window.windowID) {
                    let newFrame = CGRectTransform(cgRect: frame, display: display)
                    if newFrame != nsWindow?.frame {
                        opacity = 0
                        resizing = true
                        let newDisplay = nsWindow?.screen
                        if newFrame.size != nsWindow?.frame.size || nsScreen != newDisplay {
                            nsScreen = newDisplay
                            captureManager.updateStreamSize(newWidth: frame.width, newHeight: frame.height, screen: newDisplay)
                        }
                        nsWindow?.setFrame(CGRectTransform(cgRect: frame, display: display), display: true)
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
                    activateWindow(axWindow: axWindow, frame: CGRectTransform(cgRect: win.frame, display: display))
                    NSApp.activate(ignoringOtherApps: true)
                    bringAppToFront(bundleIdentifier: id)
                    withAnimation(.easeOut(duration: 0.1)) { opacity = 0 }
                }
            } else {
                opacity = 1
            }
        }
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
