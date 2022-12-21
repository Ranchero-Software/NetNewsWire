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
			Text("Open System Settings", comment: "Button: opens device Settings app.")
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
				Text("New Article Notifications", comment: "Button: opens New Article Notifications view")
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
				Text("Manage Accounts", comment: "Button: opens Accounts Management view")
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
				Text("Manage Extensions", comment: "Button: opens Extensions Management view")
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
				Text("Import Subscriptions", comment: "Button: opens import subscriptions view")
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
				Text("Export Subscriptions", comment: "Button: opens Export Subscriptions view")
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
			Text("Sort Oldest to Newest", comment: "Toggle: Sort articles from oldest to newest when enabled.")
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's grouping preference.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func groupByFeed(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("Group by Feed", comment: "Toggle: groups articles by feed when enabled.")
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's refresh to clear preferences.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func refreshToClearReadArticles(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("Refresh to Clear Read Articles", comment: "Toggle: when enabled, articles will be cleared when the timeline is refreshed")
		}
	}
	
	/// This row, when tapped, will push the the Timeline Layout screen
	/// in to view.
	static var timelineLayout: some View {
		NavigationLink {
			TimelineCustomizerView()
		} label: {
			Text("Timeline Layout", comment: "Button: opens the timeline customiser")
		}
	}
	
	/// This row, when tapped, will push the the Theme Selector screen
	/// in to view.
	static var themeSelection: some View {
		NavigationLink(destination: ArticleThemeManagerView()) {
			HStack {
				Text("Article Theme", comment: "Button: opens the Article Theme manager view")
				Spacer()
				Text(ArticleThemesManager.shared.currentTheme.name)
					.font(.callout)
					.foregroundColor(.secondary)
			}
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's mark all as read preferences.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func confirmMarkAllAsRead(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("Confirm Mark All as Read", comment: "Toggle: when enabled, the app will confirm whether to mark all items as read")
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's link opening behaviour.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func openLinksInNetNewsWire(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("Open Links in NetNewsWire", comment: "Toggle: when enabled, links will open in NetNewsWire")
		}
	}
	
	// TODO: Add Reader Mode Defaults here. See #3684.
	
	/// This row, when tapped, will push the New Article Notifications
	/// screen in to view.
	static func configureAppearance(_ isShown: Binding<Bool>) -> some View {
		NavigationLink(destination: DisplayAndBehaviorsView(), isActive: isShown) {
			Label {
				Text("Display & Behaviours", comment: "Button: opens the Display and Appearance view.")
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
				Text("About", comment: "Button: opens the NetNewsWire about view.")
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
