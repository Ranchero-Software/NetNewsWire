//
//  SettingsRows.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 12/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

// MARK: - Headers

struct SettingsViewHeaders {
	
	static func AddAccountHeader(_ showAddAccount: Binding<Bool>) -> some View {
		HStack {
			//Text("Accounts")
			Spacer()
			Button {
				showAddAccount.wrappedValue.toggle()
			} label: {
				Text("Add")
					.font(.caption)
					.bold()
				Image(systemName: "plus")
					.font(.caption)
			}
			.buttonBorderShape(.capsule)
			.buttonStyle(.bordered)
			.padding(.trailing, -15) // moves to trailing edge
		}
	}
	
}

// MARK: - Rows

struct SettingsViewRows {
	
	/// This row, when tapped, will open system settings.
	static var OpenSystemSettings: some View {
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
	static var ConfigureNewArticleNotifications: some View {
		NavigationLink(destination: NotificationsViewControllerRepresentable().edgesIgnoringSafeArea(.all)) {
			Label {
				Text("Notifications and Sounds")
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
	static var AddAccount: some View {
		NavigationLink(destination: AddAccountViewControllerRepresentable().edgesIgnoringSafeArea(.all)) {
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
	
	/// This `view` creates a `Label` for each active `Account`.
	/// Each `Label`, when tapped, will present the configurator for
	/// the  `Account`.
	static var ActiveAccounts: some View {
		ForEach(AccountManager.shared.sortedActiveAccounts, id: \.self) { account in
			Label {
				Text(account.nameForDisplay)
			} icon: {
				Image(uiImage: AppAssets.image(for: account.type)!)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 25.0, height: 25.0)
			}
		}
	}
	
	/// This row, when tapped, will push the the Add Extension screen
	/// in to view.
	static var AddExtension: some View {
		NavigationLink(destination: NotificationsViewControllerRepresentable()) {
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
	
	/// This row, when tapped, will push the the Import subscriptions screen
	/// in to view.
	static var ImportSubscription: some View {
		Label {
			Text("Import Subscriptions")
		} icon: {
			Image(systemName: "square.and.arrow.down")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 25.0, height: 25.0)
		}
	}
	
	/// This row, when tapped, will push the the Export subscriptions screen
	/// in to view.
	static var ExportSubscription: some View {
		Label {
			Text("Export Subscriptions")
		} icon: {
			Image(systemName: "square.and.arrow.up")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 25.0, height: 25.0)
		}
	}
	
	/// Returns a `Toggle` which triggers changes to the user's sort order preference.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func SortOldestToNewest(_ preference: Binding<Bool>) -> some View {
		Toggle("Sort Oldest to Newest", isOn: preference)
	}
	
	/// Returns a `Toggle` which triggers changes to the user's grouping preference.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func GroupByFeed(_ preference: Binding<Bool>) -> some View {
		Toggle("Group by Feed", isOn: preference)
	}
	
	/// Returns a `Toggle` which triggers changes to the user's refresh to clear preferences.
	/// - Parameter preference: `Binding<Bool>`
	/// - Returns: `Toggle`
	static func RefreshToClearReadArticles(_ preference: Binding<Bool>) -> some View {
		Toggle("Refresh To Clear Read Articles", isOn: preference)
	}
	
	/// This row, when tapped, will push the the Timeline Layout screen
	/// in to view.
	static var TimelineLayout: some View {
		NavigationLink(destination: NotificationsViewControllerRepresentable()) {
			Label {
				Text("Timeline Layout")
			} icon: {
				Image(systemName: "slider.vertical.3")
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 25.0, height: 25.0)
			}
		}
	}
	
	static var ThemeSelection: some View {
		NavigationLink(destination: ArticleThemesViewControllerRepresentable().edgesIgnoringSafeArea(.all)) {
			HStack {
				Text("Article Theme")
				Spacer()
				Text(ArticleThemesManager.shared.currentTheme.name)
					.font(.callout)
					.foregroundColor(.secondary)
			}
		}
	}
	
	static func ConfirmMarkAllAsRead(_ preference: Binding<Bool>) -> some View {
		Toggle("Confirm Mark All as Read", isOn: preference)
	}
	
	static func OpenLinksInNetNewsWire(_ preference: Binding<Bool>) -> some View {
		Toggle("Open Links in NetNewsWire", isOn: preference)
	}
	
	static func EnableFullScreenArticles(_ preference: Binding<Bool>) -> some View {
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
	static var ConfigureAppearance: some View {
		NavigationLink(destination: AppearanceManagementView()) {
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
	static func ShowHelpSheet(sheet: HelpSheet, selectedSheet: Binding<HelpSheet>, _ show: Binding<Bool>) -> some View {
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
	
	static var AboutNetNewsWire: some View {
		NavigationLink {
			AboutView()
		} label: {
			Label {
				Text("About NetNewsWire")
			} icon: {
				Image(systemName: "questionmark.square.dashed")
			}
		}
	}
}


extension Binding where Value == Bool {
	func negate() -> Bool {
		return !(self.wrappedValue)
	}
}
