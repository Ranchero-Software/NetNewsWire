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
			Picker("Refresh feeds:",
				   selection: $defaults.interval,
				   content: {
					ForEach(RefreshInterval.allCases, content: { interval in
						Text(interval.description())
							.tag(interval.rawValue)
					})
				   })

			Picker("Default RSS reader:", selection: $preferences.readerSelection, content: {
				ForEach(0..<preferences.rssReaders.count, content: { index in
					if index > 0 && preferences.rssReaders[index].nameMinusAppSuffix.contains("NetNewsWire") {
						Text(preferences.rssReaders[index].nameMinusAppSuffix.appending(" (old version)"))

					} else {
						Text(preferences.rssReaders[index].nameMinusAppSuffix)
							.tag(index)
					}
				})
			})
			
			Toggle("Confirm when deleting feeds and folders", isOn: $defaults.sidebarConfirmDelete)
			
			Toggle("Open webpages in background in browser", isOn: $defaults.openInBrowserInBackground)
			Toggle("Hide Unread Count in Dock", isOn: $defaults.hideDockUnreadCount)

			Picker("Safari Extension:",
				   selection: $defaults.subscribeToFeedsInNetNewsWire,
				   content: {
					Text("Open feeds in NetNewsWire").tag(true)
					Text("Open feeds in default news reader").tag(false)
				   }).pickerStyle(RadioGroupPickerStyle())
		}
		.frame(width: 400, alignment: .center)
		.lineLimit(2)
	}
	
}
