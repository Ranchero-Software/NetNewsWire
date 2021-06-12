//
//  GeneralPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

struct GeneralPreferencesView: View {
	
	@StateObject private var defaults = AppDefaults.shared
	@StateObject private var preferences = GeneralPreferencesModel()
	
	var body: some View {
		Form {
			Picker("Refresh feeds",
				   selection: $defaults.interval,
				   content: {
					ForEach(RefreshInterval.allCases, content: { interval in
						Text(interval.description())
							.tag(interval.rawValue)
					})
				   })
			
			Toggle("Confirm when deleting feeds and folders", isOn: $defaults.sidebarConfirmDelete)
			
			Toggle("Open webpages in background in browser", isOn: $defaults.openInBrowserInBackground)
			
			Toggle("Hide Unread Count in Dock", isOn: $defaults.hideDockUnreadCount)
			
		}
		.frame(width: 400, alignment: .center)
		.lineLimit(2)
	}
	
}
