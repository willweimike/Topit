//
//  SettingsView.swift
//  Topit
//
//  Created by apple on 2024/11/19.
//

import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @State private var selectedItem: String? = "General"
    
    var body: some View {
        NavigationView {
            List(selection: $selectedItem) {
                NavigationLink(destination: GeneralView(), tag: "General", selection: $selectedItem) {
                    Label("General", image: "gear")
                }
                NavigationLink(destination: WindowView(), tag: "Window", selection: $selectedItem) {
                    Label("Windows", image: "window")
                }
                NavigationLink(destination: HotkeyView(), tag: "Hotkey", selection: $selectedItem) {
                    Label("Hotkey", image: "hotkey")
                }
                NavigationLink(destination: FilterView(), tag: "Filter", selection: $selectedItem) {
                    Label("App Filter", image: "block")
                }
            }
            .listStyle(.sidebar)
            .padding(.top, 9)
        }
        .frame(width: 600, height: 400)
        .navigationTitle("Topit Settings")
    }
}

struct GeneralView: View {
    @AppStorage("showOnDock") private var showOnDock: Bool = true
    @AppStorage("showMenubar") private var showMenubar: Bool = true
    
    @State private var launchAtLogin = false
    
    var body: some View {
        SForm {
            SGroupBox(label: "General") {
                SToggle("Launch at Login", isOn: $launchAtLogin)
                SDivider()
                SToggle("Show Topit on Dock", isOn: $showOnDock)
                SDivider()
                SToggle("Show Topit on Menu Bar", isOn: $showMenubar)
            }
            SGroupBox(label: "Update") {
                UpdaterSettingsView(updater: updaterController.updater)
            }
            VStack(spacing: 8) {
                CheckForUpdatesView(updater: updaterController.updater)
                if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("Topit v\(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear{ launchAtLogin = (SMAppService.mainApp.status == .enabled) }
        .onChange(of: showMenubar) { newValue in statusBarItem.isVisible = newValue }
        .onChange(of: showOnDock) { newValue in
            if !newValue {
                NSApp.setActivationPolicy(.accessory)
                closeMainWindow()
            } else { NSApp.setActivationPolicy(.regular) }
        }
        .onChange(of: launchAtLogin) { newValue in
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            }catch{
                print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        }
    }
}

struct WindowView: View {
    @AppStorage("showCloseButton") private var showCloseButton: Bool = true
    @AppStorage("showUnpinButton") private var showUnpinButton: Bool = true
    @AppStorage("hasShadow") private var hasShadow: Bool = true
    @AppStorage("fullScreenFloating") private var fullScreenFloating: Bool = true
    @AppStorage("maxFps") private var maxFps: Int = 65535
    
    var body: some View {
        SForm {
            SGroupBox(label: "Windows") {
                SToggle("Floating on Top of Full-screen Apps", isOn: $fullScreenFloating)
                SDivider()
                SToggle("Show Close Button", isOn: $showCloseButton)
                SDivider()
                SToggle("Show Unpin Button", isOn: $showUnpinButton)
                SDivider()
                SToggle("Show Window Shadow", isOn: $hasShadow)
                SDivider()
                SPicker("Maximum Refresh Rate", selection: $maxFps) {
                    Text("30 Hz").tag(30)
                    Text("60 Hz").tag(60)
                    Text("120 Hz").tag(120)
                    Text("No Limit").tag(65535)
                }
            }
        }
    }
}

struct HotkeyView: View {
    var body: some View {
        SForm {
            SGroupBox(label: "Hotkey") {
                SItem(label: "Pin / Unpin Under-mouse Window") {
                    KeyboardShortcuts.Recorder("", name: .pinUnpin)
                }
                SDivider()
                SItem(label: "Unpin All Pinned Windows"){
                    KeyboardShortcuts.Recorder("", name: .unpinAll)
                }
            }
        }
    }
}

struct FilterView: View {
    @AppStorage("noTitle") var noTitle = true
    
    var body: some View {
        SForm(spacing: 10, noSpacer: true) {
            SGroupBox(label: "App Filter") {
                SToggle("Show Windows with No Title", isOn: $noTitle)
            }
            SGroupBox {
                BundleSelector()
            }
        }
    }
}

extension KeyboardShortcuts.Name {
    static let pinUnpin = Self("pinUnpin")
    static let unpinAll = Self("unpinAll")
}
