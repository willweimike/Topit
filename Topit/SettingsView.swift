//
//  SettingsView.swift
//  Topit
//
//  Created by apple on 2024/11/19.
//

import SwiftUI

struct SettingsView: View {
    var fromPanel: Bool = false
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("noTitle") var noTitle = true
    
    var body: some View {
        VStack(spacing: -10) {
            Form {
                Section {
                    Toggle("Show Windows with No Title", isOn: $noTitle)
                }
                Section {
                    UpdaterSettingsView(updater: updaterController.updater)
                }
            }.formStyle(.grouped)
            if fromPanel {
                HStack {
                    CheckForUpdatesView(updater: updaterController.updater)
                    if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("Topit v\(appVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 17)
            }
        }
    }
}
