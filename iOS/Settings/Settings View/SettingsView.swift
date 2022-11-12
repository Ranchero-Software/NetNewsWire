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
	@State private var showAbout: Bool = false
		
	var body: some View {
		NavigationView {
			List {
				
				// System Settings
				Section(footer: Text("Configure access to Siri, background app refresh, mobile data, and more.")) {
					SettingsViewRows.OpenSystemSettings
				}
				
				Section(footer: Text("Add, delete, or disable accounts and extensions.")) {
					SettingsViewRows.AddAccount
					SettingsViewRows.AddExtension
				}
				
				Section(footer: Text("Configure the look and feel of NetNewsWire.")) {
					SettingsViewRows.ConfigureNewArticleNotifications
					SettingsViewRows.ConfigureAppearance
				}
				
				
								
				Section {
					ForEach(0..<HelpSheet.allCases.count, id: \.self) { i in
						SettingsViewRows.ShowHelpSheet(sheet: HelpSheet.allCases[i], selectedSheet: $helpSheet, $showHelpSheet)
					}
					SettingsViewRows.AboutNetNewsWire

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
			.sheet(isPresented: $showAbout) {
				AboutView()
			}
		}
	}
}
