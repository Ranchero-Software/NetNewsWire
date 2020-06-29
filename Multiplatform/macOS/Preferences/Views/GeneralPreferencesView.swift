//
//  GeneralPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

struct GeneralPreferencesView: View {
    
    @ObservedObject private var preferences = MacPreferences()
    
    var body: some View {
        VStack {
            Form {
                Picker("Refresh Feeds",
                       selection: $preferences.refreshFrequency,
                       content: {
                    ForEach(0..<preferences.refreshIntervals.count, content: {
                        Text(preferences.refreshIntervals[$0])
                    })
                }).frame(width: 300, alignment: .center)
                
                Toggle("Open webpages in background in browser", isOn: $preferences.openInBackground)
                
                Toggle("Show Unread Count in Dock", isOn: $preferences.showUnreadCountInDock)
            }
            Spacer()
        }.frame(width: 300, alignment: .center)
    }
    
}
