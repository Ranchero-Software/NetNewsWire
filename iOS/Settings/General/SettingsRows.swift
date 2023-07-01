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

struct SettingsRow {
	
	/// This row, when tapped, will open iOS System Settings.
	static var openSystemSettings: some View {
		Label {
			Text("button.title.open-system-settings", comment: "Open System Settings")
		} icon: {
			Image("system.settings")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 25.0, height: 25.0)
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
				Text("button.title.new-article-notifications", comment: "New Article Notifications")
			} icon: {
				Image("notifications.sounds")
					.resizable()
					.frame(width: 25.0, height: 25.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	/// This row, when tapped, will push the the Add Account screen
	/// in to view.
	static var addAccount: some View {
		NavigationLink(destination: AccountsManagementView()) {
			Label {
				Text("button.title.manage-accounts", comment: "Manage Accounts")
			} icon: {
				Image("app.account")
					.resizable()
					.frame(width: 25.0, height: 25.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	
	/// Toggle for determining if articles are marked as read when scrolling the timeline view.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `some View`
	static func markAsReadOnScroll(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("Mark As Read on Scroll", comment: "Mark As Read on Scroll")
		}
	}
	
	/// This row, when tapped, will present the Import
	/// Subscriptions Action Sheet.
	static func importOPML(showImportActionSheet: Binding<Bool>) -> some View {
		Button {
			showImportActionSheet.wrappedValue.toggle()
		} label: {
			Label {
				Text("button.title.import-subscriptions", comment: "Import Subscriptions")
					.foregroundColor(.primary)
				
			} icon: {
				Image("app.import.opml")
					.resizable()
					.frame(width: 25.0, height: 25.0)
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
				Text("button.title.export-subscriptions", comment: "Export Subscriptions")
					.foregroundColor(.primary)
				
			} icon: {
				Image("app.export.opml")
					.resizable()
					.frame(width: 25.0, height: 25.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's sort order preference.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func sortOldestToNewest(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("toggle.title.sort-oldest-to-newest", comment: "Sort Oldest to Newest")
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's grouping preference.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func groupByFeed(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("toggle.title.group-by-feed", comment: "Group by Feed")
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's refresh to clear preferences.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func refreshToClearReadArticles(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("toggle.title.refresh-to-clear-articles", comment: "Refresh to Clear Articles")
		}
	}
	
	/// This row, when tapped, will push the the Timeline Layout screen
	/// in to view.
	static var timelineLayout: some View {
		NavigationLink {
			TimelineCustomizerView()
		} label: {
			Text("button.title.timeline-layout", comment: "Timeline Layout")
		}
	}
	
	/// This row, when tapped, will push the the Theme Selector screen
	/// in to view.
	static var themeSelection: some View {
		NavigationLink(destination: ArticleThemeManagerView()) {
			HStack {
				Text("button.title.artice-themes", comment: "Article Themes")
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
			Text("toggle.title.confirm-mark-all-as-read", comment: "Confirm Mark All as Read")
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's link opening behaviour.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func openLinksInNetNewsWire(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			Text("toggle.title.open-links-in-netnewswire", comment: "Open Links in NetNewsWire")
		}
	}
	
	// TODO: Add Reader Mode Defaults here. See #3684.
	
	/// This row, when tapped, will push the New Article Notifications
	/// screen in to view.
	static func configureAppearance(_ isShown: Binding<Bool>) -> some View {
		NavigationLink {
			DisplayAndBehaviorsView()
		} label: {
			Label {
				Text("button.title.display-and-behaviors", comment: "Display & Behaviors")
			} icon: {
				Image("app.appearance")
					.resizable()
					.frame(width: 25.0, height: 25.0)
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
				.symbolRenderingMode(.hierarchical)
				.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
				.aspectRatio(contentMode: .fit)
				.frame(width: 25.0, height: 25.0)
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
				Text("button.title.about", comment: "About")
			} icon: {
				Image(systemName: "info.circle.fill")
					.resizable()
					.renderingMode(.template)
					.symbolRenderingMode(.hierarchical)
					.foregroundColor(Color(uiColor: AppAssets.primaryAccentColor))
					.aspectRatio(contentMode: .fit)
					.frame(width: 25.0, height: 25.0)
			}
		}
	}
}
