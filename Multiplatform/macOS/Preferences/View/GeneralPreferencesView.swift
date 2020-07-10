//
//  GeneralPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

struct GeneralPreferencesView: View {
    
	@EnvironmentObject private var defaults: AppDefaults
    
    var body: some View {
        VStack {
            Form {
                Picker("Refresh Feeds",
					   selection: $defaults.interval,
                       content: {
						ForEach(RefreshInterval.allCases, content: { interval in
							Text(interval.description()).tag(interval.rawValue)
                    })
					   }).frame(width: 300, alignment: .center)
				
                Toggle("Open webpages in background in browser", isOn: $defaults.openInBrowserInBackground)
                
                Toggle("Hide Unread Count in Dock", isOn: $defaults.hideDockUnreadCount)
            }
            Spacer()
		}.frame(width: 300, alignment: .center)
    }
    
}
