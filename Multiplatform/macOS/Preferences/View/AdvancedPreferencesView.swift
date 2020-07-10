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
        VStack {
            Form {
                Toggle("Check for app updates automatically", isOn: $preferences.checkForUpdatesAutomatically)
                
                Toggle("Download Test Builds", isOn: $preferences.downloadTestBuilds)
                HStack {
                    Spacer()
                    Text("If you’re not sure, don't enable test builds. Test builds may have bugs, which may include crashing bugs and data loss.").foregroundColor(.secondary)
                    Spacer()
                }
                
                HStack {
                    Spacer()
                    Button("Check for Updates", action: {})
                    Spacer()
                }.padding(.vertical, 12)
                
                
                Toggle("Send Crash Logs Automatically", isOn: $preferences.sendCrashLogs)
                
                Spacer()
                HStack {
                    Spacer()
                    Button("Privacy Policy", action: {})
                    Spacer()
                }.padding(.top, 12)
                
                
            }
            Spacer()
        }.frame(width: 300, alignment: .center)
    }
    
}

