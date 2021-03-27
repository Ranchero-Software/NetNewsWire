//
//  AdvancedPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

struct AdvancedPreferencesView: View {
    
	@StateObject private var preferences = AppDefaults.shared
	@StateObject private var viewModel = AdvancedPreferencesModel()
    
    var body: some View {
            Form {
                Toggle("Check for app updates automatically", isOn: $preferences.checkForUpdatesAutomatically)
                Toggle("Download Test Builds", isOn: $preferences.downloadTestBuilds)
				Text("If you’re not sure, don't enable test builds. Test builds may have bugs, which may include crashing bugs and data loss.")
					.foregroundColor(.secondary)
                HStack {
                    Spacer()
					Button("Check for Updates") {
						appDelegate.softwareUpdater.checkForUpdates()
					}
                    Spacer()
                }
                Toggle("Send Crash Logs Automatically", isOn: $preferences.sendCrashLogs)
				Divider()
                HStack {
                    Spacer()
                    Button("Privacy Policy", action: {
						NSWorkspace.shared.open(URL(string: "https://netnewswire.com/privacypolicy")!)
					})
                    Spacer()
                }
			}
			.onChange(of: preferences.downloadTestBuilds, perform: { _ in
				viewModel.updateAppcast()
			})
			.frame(width: 400, alignment: .center)
			.lineLimit(3)
    }
    
}

