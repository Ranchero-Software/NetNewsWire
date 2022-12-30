//
//  DisplayAndBehaviorsView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 12/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI

struct DisplayAndBehaviorsView: View {
    
	@StateObject private var appDefaults = AppDefaults.shared
	
	var body: some View {
		List {
			Section(header: Text("label.text.application", comment: "Application")) {
				ColorPaletteSelectorView()
				.listRowBackground(Color.clear)
			}
			
			Section(header: Text("label.text.timeline", comment: "Timeline")) {
				SettingsViewRows.sortOldestToNewest($appDefaults.timelineSortDirectionBool)
				SettingsViewRows.groupByFeed($appDefaults.timelineGroupByFeed)
				SettingsViewRows.refreshToClearReadArticles($appDefaults.refreshClearsReadArticles)
				SettingsViewRows.timelineLayout
			}
			
			Section(header: Text("label.text.articles", comment: "Articles")) {
				SettingsViewRows.themeSelection
				SettingsViewRows.confirmMarkAllAsRead($appDefaults.confirmMarkAllAsRead)
				SettingsViewRows.openLinksInNetNewsWire(Binding<Bool>(
					get: { !appDefaults.useSystemBrowser },
					set: { appDefaults.useSystemBrowser = !$0 }
				))
				// TODO: Add Reader Mode Defaults here. See #3684.
			}
		}
		.navigationTitle(Text("navigation.title.display-and-behaviors", comment: "Display & Behaviors"))
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
    }
	
	
	
}

struct AppearanceManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DisplayAndBehaviorsView()
    }
}
