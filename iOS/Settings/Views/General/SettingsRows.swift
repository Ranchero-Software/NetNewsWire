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
			Text("Open System Settings")
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
				Text("New Article Notifications")
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
				Text("Manage Accounts")
			} icon: {
				Image("app.account")
					.resizable()
					.frame(width: 25.0, height: 25.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	/// This row, when tapped, will push the the Manage Extension screen
	/// in to view.
	static var manageExtensions: some View {
		NavigationLink(destination: ExtensionsManagementView()) {
			Label {
				Text("Manage Extensions")
			} icon: {
				Image("app.extension")
					.resizable()
					.frame(width: 25.0, height: 25.0)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}
	
	/// This row, when tapped, will present an Import/Export
	/// menu.
	static func importExportOPML(showImportView: Binding<Bool>, showExportView: Binding<Bool>, importAccount: Binding<Account?>, exportDocument: Binding<OPMLDocument?>) -> some View {
		Menu {
			Menu {
				ForEach(AccountManager.shared.sortedActiveAccounts, id: \.self) { account in
					Button(account.nameForDisplay) {
						importAccount.wrappedValue = account
						showImportView.wrappedValue = true
					}
				}
			} label: {
				Label("Import Subscriptions To...", systemImage: "arrow.down.doc")
			}
			Divider()
			Menu {
				ForEach(AccountManager.shared.sortedAccounts, id: \.self) { account in
					Button(account.nameForDisplay) {
						do {
							let document = try OPMLDocument(account)
							exportDocument.wrappedValue = document
							showExportView.wrappedValue = true
						} catch {
							print(error.localizedDescription)
						}
					}
				}
			} label: {
				Label("Export Subscriptions From...", systemImage: "arrow.up.doc")
			}
		} label: {
			Label {
				Text("Import/Export Subscriptions")
					.foregroundColor(.primary)
				
			} icon: {
				Image("app.opml")
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
		Toggle("Sort Oldest to Newest", isOn: preference)
	}
	
	/// Returns a `Toggle` which triggers changes to the user's grouping preference.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func groupByFeed(_ preference: Binding<Bool>) -> some View {
		Toggle("Group by Feed", isOn: preference)
	}
	
	/// Returns a `Toggle` which triggers changes to the user's refresh to clear preferences.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func refreshToClearReadArticles(_ preference: Binding<Bool>) -> some View {
		Toggle("Refresh To Clear Read Articles", isOn: preference)
	}
	
	/// This row, when tapped, will push the the Timeline Layout screen
	/// in to view.
	static var timelineLayout: some View {
		NavigationLink(destination: TimelineCustomizerWrapper().edgesIgnoringSafeArea(.all).navigationTitle(Text("Timeline Layout"))) {
			Text("Timeline Layout")
		}
	}
	
	/// This row, when tapped, will push the the Theme Selector screen
	/// in to view.
	static var themeSelection: some View {
		NavigationLink(destination: ArticleThemesWrapper().edgesIgnoringSafeArea(.all)) {
			HStack {
				Text("Article Theme")
				Spacer()
				Text(ArticleThemesManager.shared.currentTheme.name)
					.font(.callout)
					.foregroundColor(.secondary)
			}
		}
	}
	
	static func confirmMarkAllAsRead(_ preference: Binding<Bool>) -> some View {
		Toggle("Confirm Mark All as Read", isOn: preference)
	}
	
	static func openLinksInNetNewsWire(_ preference: Binding<Bool>) -> some View {
		Toggle("Open Links in NetNewsWire", isOn: preference)
	}
	
	// TODO: Add Reader Mode Defaults here. See #3684.
	static func enableFullScreenArticles(_ preference: Binding<Bool>) -> some View {
		Toggle(isOn: preference) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Enable Full Screen Articles")
				Text("Tap the article top bar to enter Full Screen. Tap the top or bottom to exit.")
					.font(.caption)
					.foregroundColor(.gray)
			}
		}
	}
	
	/// This row, when tapped, will push the New Article Notifications
	/// screen in to view.
	static func configureAppearance(_ isShown: Binding<Bool>) -> some View {
		NavigationLink(destination: DisplayAndBehaviorsView(), isActive: isShown) {
			Label {
				Text("Display & Behaviors")
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
				.foregroundColor(Color(uiColor: .tertiaryLabel))
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
				Text("About NetNewsWire")
			} icon: {
				Image(systemName: "info.circle")
					.resizable()
					.renderingMode(.template)
					.foregroundColor(Color(uiColor: .tertiaryLabel))
					.aspectRatio(contentMode: .fit)
					.frame(width: 25.0, height: 25.0)
			}
		}
	}
}
