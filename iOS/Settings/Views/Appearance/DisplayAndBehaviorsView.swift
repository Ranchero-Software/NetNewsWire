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
			Section("Application") {
				ColorPaletteSelectorView()
				.listRowBackground(Color.clear)
			}
			
			Section("Timeline") {
				SettingsViewRows.SortOldestToNewest($appDefaults.timelineSortDirectionBool)
				SettingsViewRows.GroupByFeed($appDefaults.timelineGroupByFeed)
				SettingsViewRows.RefreshToClearReadArticles($appDefaults.refreshClearsReadArticles)
				SettingsViewRows.TimelineLayout
			}
			
			Section("Article") {
				SettingsViewRows.ThemeSelection
				SettingsViewRows.ConfirmMarkAllAsRead($appDefaults.confirmMarkAllAsRead)
				SettingsViewRows.OpenLinksInNetNewsWire(Binding<Bool>(
					get: { !appDefaults.useSystemBrowser },
					set: { appDefaults.useSystemBrowser = !$0 }
				))
				// TODO: Add Reader Mode Defaults here. See #3684.
			}
		}
		.navigationTitle(Text("Display & Behaviors"))
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
    }
	
	
	
}

struct AppearanceManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DisplayAndBehaviorsView()
    }
}
