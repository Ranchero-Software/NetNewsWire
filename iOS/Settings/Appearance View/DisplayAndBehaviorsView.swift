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
				HStack {
					appLightButton()
					Spacer()
					appDarkButton()
					Spacer()
					appAutomaticButton()
				}
				.listRowBackground(Color.clear)
			}
			
			Section("Timeline") {
				SettingsViewRows.SortOldestToNewest($appDefaults.timelineSortDirectionBool)
				SettingsViewRows.GroupByFeed($appDefaults.timelineGroupByFeed)
				SettingsViewRows.RefreshToClearReadArticles($appDefaults.refreshClearsReadArticles)
			}
			
			Section("Article") {
				SettingsViewRows.ThemeSelection
				SettingsViewRows.ConfirmMarkAllAsRead($appDefaults.confirmMarkAllAsRead)
				SettingsViewRows.OpenLinksInNetNewsWire(Binding<Bool>(
					get: { !appDefaults.useSystemBrowser },
					set: { appDefaults.useSystemBrowser = !$0 }
				))
			}
		}
		.navigationTitle(Text("Display & Behaviors"))
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
    }
	
	func appLightButton() -> some View {
		VStack(spacing: 4) {
			Image("app.appearance.light")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 40.0, height: 40.0)
			Text("Always Light")
				.font(.subheadline)
			if AppDefaults.userInterfaceColorPalette == .light {
				Image(systemName: "checkmark.circle.fill")
					.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
			} else {
				Image(systemName: "circle")
			}
		}.onTapGesture {
			AppDefaults.userInterfaceColorPalette = .light
		}
	}
	
	func appDarkButton() -> some View {
		VStack(spacing: 4) {
			Image("app.appearance.dark")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 40.0, height: 40.0)
			Text("Always Dark")
				.font(.subheadline)
			if AppDefaults.userInterfaceColorPalette == .dark {
				Image(systemName: "checkmark.circle.fill")
					.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
			} else {
				Image(systemName: "circle")
			}
		}.onTapGesture {
			AppDefaults.userInterfaceColorPalette = .dark
		}
	}
	
	func appAutomaticButton() -> some View {
		VStack(spacing: 4) {
			Image("app.appearance.automatic")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 40.0, height: 40.0)
			Text("Use System")
				.font(.subheadline)
			if AppDefaults.userInterfaceColorPalette == .automatic {
				Image(systemName: "checkmark.circle.fill")
					.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
			} else {
				Image(systemName: "circle")
			}
		}.onTapGesture {
			AppDefaults.userInterfaceColorPalette = .automatic
		}
	}
	
}

struct AppearanceManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DisplayAndBehaviorsView()
    }
}
