//
//  AdvancedPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

struct AdvancedPreferencesView: View {
    
	@EnvironmentObject private var preferences: AppDefaults
    
    var body: some View {
        
            Form {
                Toggle("Check for app updates automatically", isOn: $preferences.checkForUpdatesAutomatically)
                
                Toggle("Download Test Builds", isOn: $preferences.downloadTestBuilds)
				
				Text("If you’re not sure, don't enable test builds. Test builds may have bugs, which may include crashing bugs and data loss.")
					.foregroundColor(.secondary)
					.lineLimit(3)
					.padding(.bottom, 8)
                
                HStack {
                    Spacer()
                    Button("Check for Updates", action: {})
                    Spacer()
                }.padding(.bottom, 8)
                
                
                Toggle("Send Crash Logs Automatically", isOn: $preferences.sendCrashLogs)
                
                HStack {
                    Spacer()
                    Button("Privacy Policy", action: {
						NSWorkspace.shared.open(URL(string: "https://ranchero.com/netnewswire/privacypolicy")!)
					})
                    Spacer()
                }.padding(.top, 12)
			}.frame(width: 400, alignment: .center)
    }
    
}

