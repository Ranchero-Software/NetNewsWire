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
			Section(header: Text("Application", comment: "Display & Behaviours: Application section header")) {
				ColorPaletteSelectorView()
				.listRowBackground(Color.clear)
			}
			
			Section(header: Text("Timeline", comment: "Display & Behaviours: Timeline section header")) {
				SettingsViewRows.sortOldestToNewest($appDefaults.timelineSortDirectionBool)
				SettingsViewRows.groupByFeed($appDefaults.timelineGroupByFeed)
				SettingsViewRows.confirmMarkAllAsRead($appDefaults.confirmMarkAllAsRead)
				SettingsViewRows.markAsReadOnScroll($appDefaults.markArticlesAsReadOnScroll)
				SettingsViewRows.refreshToClearReadArticles($appDefaults.refreshClearsReadArticles)
				SettingsViewRows.timelineLayout
			}
			
			Section(header: Text("Article", comment: "Display & Behaviours: Article section header")) {
				SettingsViewRows.themeSelection
				SettingsViewRows.openLinksInNetNewsWire(Binding<Bool>(
					get: { !appDefaults.useSystemBrowser },
					set: { appDefaults.useSystemBrowser = !$0 }
				))
				// TODO: Add Reader Mode Defaults here. See #3684.
			}
		}
		.navigationTitle(Text("Display & Behaviors", comment: "Navigation title for Display & Behaviours"))
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
    }
	
	
	
}

struct AppearanceManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DisplayAndBehaviorsView()
    }
}
