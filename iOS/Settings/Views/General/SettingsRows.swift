//
//  SettingsRows.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 12/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import UniformTypeIdentifiers


// MARK: - Rows

struct SettingsViewRows {
	
	/// This row, when tapped, will open iOS System Settings.
	static var openSystemSettings: some View {
		Label {
			Text("OPEN_SYSTEM_SETTINGS", tableName: "Settings")
		} icon: {
			Image("system.settings")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 30.0, height: 30.0)
				.clipShape(RoundedRectangle(cornerRadius: 6))
		}
		.onTapGesture {
			UIApplication.shared.open(URL(string: "\(UIApplication.openSettingsURLString)")!)
		}
	}
	
	/// This row, when tapped, will push the New Article Notifications
	/// screen in to view.
	static var configureNewArticleNotifications: some View {
		NavigationLink(destination: NewArticleNotificationsView()) {
			Label {
				Text("NEW_ARTICLE_NOTIFICATIONS", tableName: "Settings")
			} icon: {
				Image("notifications.sounds")
					.resizable()
					.frame(width: 30.0, height: 30.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	/// This row, when tapped, will push the the Add Account screen
	/// in to view.
	static var addAccount: some View {
		NavigationLink(destination: AccountsManagementView()) {
			Label {
				Text("MANAGE_ACCOUNTS", tableName: "Settings")
			} icon: {
				Image("app.account")
					.resizable()
					.frame(width: 30.0, height: 30.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	/// This row, when tapped, will push the the Manage Extension screen
	/// in to view.
	static var manageExtensions: some View {
		NavigationLink(destination: ExtensionsManagementView()) {
			Label {
				Text("MANAGE_EXTENSIONS", tableName: "Settings")
			} icon: {
				Image("app.extension")
					.resizable()
					.frame(width: 30.0, height: 30.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	/// This row, when tapped, will present the Import
	/// Subscriptions Action Sheet.
	static func importOPML(showImportActionSheet: Binding<Bool>) -> some View {
		Button {
			showImportActionSheet.wrappedValue.toggle()
		} label: {
			Label {
				Text("IMPORT_SUBSCRIPTIONS", tableName: "Settings")
					.foregroundColor(.primary)
				
			} icon: {
				Image("app.import.opml")
					.resizable()
					.frame(width: 30.0, height: 30.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	/// This row, when tapped, will present the Export
	/// Subscriptions Action Sheet.
	static func exportOPML(showExportActionSheet: Binding<Bool>) -> some View {
		Button {
			showExportActionSheet.wrappedValue.toggle()
		} label: {
			Label {
				Text("EXPORT_SUBSCRIPTIONS", tableName: "Settings")
					.foregroundColor(.primary)
				
			} icon: {
				Image("app.export.opml")
					.resizable()
					.frame(width: 30.0, height: 30.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's sort order preference.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func sortOldestToNewest(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("SORT_OLDEST_NEWEST", tableName: "Settings")
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's grouping preference.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func groupByFeed(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("GROUP_BY_FEED", tableName: "Settings")
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's refresh to clear preferences.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func refreshToClearReadArticles(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("REFRESH_TO_CLEAR_READ_ARTICLES", tableName: "Settings")
		}
	}
	
	/// This row, when tapped, will push the the Timeline Layout screen
	/// in to view.
	static var timelineLayout: some View {
		NavigationLink(destination: TimelineCustomizerWrapper().edgesIgnoringSafeArea(.all).navigationTitle(Text("TIMELINE_LAYOUT", tableName: "Settings"))) {
			Text("TIMELINE_LAYOUT", tableName: "Settings")
		}
	}
	
	/// This row, when tapped, will push the the Theme Selector screen
	/// in to view.
	static var themeSelection: some View {
		NavigationLink(destination: ArticleThemesWrapper().edgesIgnoringSafeArea(.all)) {
			HStack {
				Text("ARTICLE_THEME", tableName: "Settings")
				Spacer()
				Text(ArticleThemesManager.shared.currentTheme.name)
					.font(.callout)
					.foregroundColor(.secondary)
			}
		}
	}
	
	static func confirmMarkAllAsRead(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("CONFIRM_MARK_ALL_AS_READ", tableName: "Settings")
		}
	}
	
	static func openLinksInNetNewsWire(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("OPEN_LINKS_IN_APP", tableName: "Settings")
		}
	}
	
	// TODO: Add Reader Mode Defaults here. See #3684.
	
	/// This row, when tapped, will push the New Article Notifications
	/// screen in to view.
	static func configureAppearance(_ isShown: Binding<Bool>) -> some View {
		NavigationLink(destination: DisplayAndBehaviorsView(), isActive: isShown) {
			Label {
				Text("DISPLAY_BEHAVIORS_HEADER", tableName: "Settings")
			} icon: {
				Image("app.appearance")
					.resizable()
					.frame(width: 30.0, height: 30.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	/// Sets the help sheet the user wishes to see.
	/// - Parameters:
	///   - sheet: The sheet provided to create the view.
	///   - selectedSheet: A `Binding` to the currently selected sheet. This is set, followed by `show`.
	///   - show: A `Binding` to `Bool` which triggers the sheet to display.
	/// - Returns: `View`
	static func showHelpSheet(sheet: HelpSheet, selectedSheet: Binding<HelpSheet>, _ show: Binding<Bool>) -> some View {
		Label {
			Text(sheet.description)
		} icon: {
			Image(systemName: sheet.systemImage)
				.resizable()
				.renderingMode(.template)
				.foregroundColor(Color(uiColor: .tertiaryLabel))
				.aspectRatio(contentMode: .fit)
				.frame(width: 30.0, height: 30.0)
		}
		.onTapGesture {
			selectedSheet.wrappedValue = sheet
			show.wrappedValue.toggle()
		}
	}
	
	static var aboutNetNewsWire: some View {
		NavigationLink {
			AboutView()
		} label: {
			Label {
				Text("ABOUT", tableName: "Settings")
			} icon: {
				Image(systemName: "info.circle")
					.resizable()
					.renderingMode(.template)
					.foregroundColor(Color(uiColor: .tertiaryLabel))
					.aspectRatio(contentMode: .fit)
					.frame(width: 30.0, height: 30.0)
			}
		}
	}
}
