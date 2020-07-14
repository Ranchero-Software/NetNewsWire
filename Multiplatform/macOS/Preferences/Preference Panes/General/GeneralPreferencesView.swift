//
//  GeneralPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI

struct GeneralPreferencesView: View {
	
	@EnvironmentObject private var defaults: AppDefaults
	@Environment(\.colorScheme) private var colorScheme
	@ObservedObject var preferences: MacPreferencesModel
	private let colorPalettes = UserInterfaceColorPalette.allCases
	
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
			
			Picker("Default RSS reader", selection: $preferences.readerSelection, content: {
				ForEach(0..<preferences.rssReaders.count, content: { index in
					if index > 0 && preferences.rssReaders[index].nameMinusAppSuffix.contains("NetNewsWire") {
						Text(preferences.rssReaders[index].nameMinusAppSuffix.appending(" (old version)"))

					} else {
						Text(preferences.rssReaders[index].nameMinusAppSuffix)
							.tag(index)
					}
				})
			})
			
			
			Toggle("Open webpages in background in browser", isOn: $defaults.openInBrowserInBackground)
			
			Toggle("Hide Unread Count in Dock", isOn: $defaults.hideDockUnreadCount)
			
			Divider()
			
			Picker("Appearance", selection: $defaults.userInterfaceColorPalette, content: {
				ForEach(colorPalettes, id: \.self, content: {
					Text($0.description)
				})
			}).pickerStyle(RadioGroupPickerStyle())
			
			
		}
		.frame(width: 400, alignment: .center)
		.lineLimit(2)
	}
	
}
