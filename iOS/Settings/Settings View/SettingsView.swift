//
//  SettingsView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 12/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsView: View {
	
	@StateObject private var appDefaults = AppDefaults.shared
	@State private var showAddAccountView: Bool = false
	@State private var helpSheet: HelpSheet = .help
	@State private var showHelpSheet: Bool = false
		
	var body: some View {
		NavigationView {
			List {
				Section("Notifications, Badge, Data, and More") {
					SettingsViewRows.OpenSystemSettings
					SettingsViewRows.ConfigureNewArticleNotifications
				}
				
				Section(header: SettingsViewHeaders.AddAccountHeader($showAddAccountView)) {
					SettingsViewRows.ActiveAccounts
				}
				
				Section("Extensions") {
					SettingsViewRows.AddExtension
				}
				
				Section("Subscriptions") {
					SettingsViewRows.ImportSubscription
					SettingsViewRows.ExportSubscription
				}
				
				Section("Timeline") {
					SettingsViewRows.SortOldestToNewest($appDefaults.timelineSortDirectionBool)
					SettingsViewRows.GroupByFeed($appDefaults.timelineGroupByFeed)
					SettingsViewRows.RefreshToClearReadArticles($appDefaults.refreshClearsReadArticles)
					SettingsViewRows.TimelineLayout
				}
				
				Section("Articles") {
					SettingsViewRows.ThemeSelection
					SettingsViewRows.ConfirmMarkAllAsRead($appDefaults.confirmMarkAllAsRead)
					SettingsViewRows.OpenLinksInNetNewsWire($appDefaults.useSystemBrowser)
					SettingsViewRows.EnableFullScreenArticles($appDefaults.articleFullscreenEnabled)
				}
				
				Section("Appearance") {
					SettingsViewRows.ConfigureAppearance
				}
				
				Section("Help") {
					ForEach(0..<HelpSheet.allCases.count, id: \.self) { i in
						SettingsViewRows.ShowHelpSheet(sheet: HelpSheet.allCases[i], selectedSheet: $helpSheet, $showHelpSheet)
					}
				}
			}
			.tint(Color(uiColor: AppAssets.primaryAccentColor))
			.listStyle(.insetGrouped)
			.navigationTitle(Text("Settings"))
			.navigationBarTitleDisplayMode(.inline)
			.sheet(isPresented: $showAddAccountView) {
				AddAccountViewControllerRepresentable().edgesIgnoringSafeArea(.all)
			}
			.sheet(isPresented: $showHelpSheet) {
				SafariView(url: helpSheet.url)
			}
		}
	}
}
