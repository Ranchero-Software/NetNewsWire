//
//  SettingsView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Combine
import Account

struct SettingsView : View {
	
	@ObservedObject var viewModel: ViewModel

	@Environment(\.viewController) private var viewController: UIViewController?
	@Environment(\.sceneCoordinator) private var coordinator: SceneCoordinator?

	@State private var accountAction: Int? = nil
	@State private var refreshAction: Int? = nil
	@State private var aboutAction: Int? = nil

	@State private var isWebsitePresented: Bool = false
	@State private var website: String? = nil
	
	@State private var isOPMLImportPresented: Bool = false
	@State private var isOPMLImportDocPickerPresented: Bool = false
	@State private var isOPMLExportPresented: Bool = false
	@State private var isOPMLExportDocPickerPresented: Bool = false
	@State private var opmlAccount: Account? = nil

    var body: some View {
		NavigationView {
			Form {
				buildAccountsSection()
				buildTimelineSection()
				buildDatabaseSection()
				buildAboutSection()
			}
			.buttonStyle(VibrantButtonStyle(alignment: .leading))
			.navigationBarTitle(Text("Settings"), displayMode: .inline)
			.navigationBarItems(leading: Button(action: { self.viewController?.dismiss(animated: true) }) { Text("Done") } )
		}
    }
	
	func buildAccountsSection() -> some View {
		Section(header: Text("ACCOUNTS").padding(.top, 22.0)) {
			ForEach(viewModel.accounts.indices, id: \.self) { index in
				NavigationLink(destination: SettingsDetailAccountView(viewModel: SettingsDetailAccountView.ViewModel(self.viewModel.accounts[index])), tag: index, selection: self.$accountAction) {
					Text(verbatim: self.viewModel.accounts[index].nameForDisplay)
				}
				.modifier(VibrantSelectAction(action: {
					self.accountAction = index
				}))
			}
			NavigationLink(destination: SettingsAddAccountView(), tag: 1000, selection: $accountAction) {
				Text("Add Account")
			}
			.modifier(VibrantSelectAction(action: {
				self.accountAction = 1000
			}))
		}
	}
	
	func buildTimelineSection() -> some View {
		Section(header: Text("TIMELINE")) {
			Toggle(isOn: $viewModel.sortOldestToNewest) {
				Text("Sort Newest to Oldest")
			}
			Toggle(isOn: $viewModel.groupByFeed) {
				Text("Group By Feed")
			}
			Stepper(value: $viewModel.timelineNumberOfLines, in: 2...6) {
				Text("Number of Text Lines: \(viewModel.timelineNumberOfLines)")
			}
		}
	}
	
	func buildDatabaseSection() -> some View {
		Section(header: Text("DATABASE")) {

			NavigationLink(destination: SettingsRefreshSelectionView(selectedInterval: $viewModel.refreshInterval), tag: 1, selection: $refreshAction) {
				HStack {
					Text("Refresh Interval")
					Spacer()
					Text(verbatim: self.viewModel.refreshInterval.description()).foregroundColor(.secondary)
				}
			}
			.modifier(VibrantSelectAction(action: {
				self.refreshAction = 1
			}))
			
			Button("Import Subscriptions...") {
				if AccountManager.shared.activeAccounts.count == 1 {
					self.opmlAccount = AccountManager.shared.activeAccounts.first
					self.isOPMLImportDocPickerPresented = true
				} else {
					self.isOPMLImportPresented = true
				}
			}.actionSheet(isPresented: $isOPMLImportPresented) {
				buildSubscriptionsImportAccounts()
			}.sheet(isPresented: $isOPMLImportDocPickerPresented) {
				SettingsSubscriptionsImportDocumentPickerView(account: self.opmlAccount!)
			}
			
			 Button("Export Subscriptions...") {
				if AccountManager.shared.accounts.count == 1 {
					self.opmlAccount = AccountManager.shared.accounts.first
					self.isOPMLImportDocPickerPresented = true
				} else {
					self.isOPMLExportPresented = true
				}
			 }.actionSheet(isPresented: $isOPMLExportPresented) {
				buildSubscriptionsExportAccounts()
			 }.sheet(isPresented: $isOPMLExportDocPickerPresented) {
				 SettingsSubscriptionsExportDocumentPickerView(account: self.opmlAccount!)
			 }
		}
	}
	
	func buildAboutSection() -> some View {
		Section(header: Text("ABOUT"), footer: buildFooter()) {

			NavigationLink(destination: SettingsAboutView(viewModel: SettingsAboutView.ViewModel()), tag: 1, selection: $aboutAction) {
				Text("About NetNewsWire")
			}
			.modifier(VibrantSelectAction(action: {
				self.aboutAction = 1
			}))
			
			Button(action: {
				self.isWebsitePresented.toggle()
				self.website = "https://ranchero.com/netnewswire/"
			}) {
				Text("Website")
			}
			
			Button(action: {
				self.isWebsitePresented.toggle()
				self.website = "https://github.com/brentsimmons/NetNewsWire"
			}) {
				Text("Github Repository")
			}
			
			Button(action: {
				self.isWebsitePresented.toggle()
				self.website = "https://github.com/brentsimmons/NetNewsWire/issues"
			}) {
				Text("Bug Tracker")
			}
			
			Button(action: {
				self.isWebsitePresented.toggle()
				self.website = "https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes"
			}) {
				Text("Technotes")
			}
			
			Button(action: {
				self.isWebsitePresented.toggle()
				self.website = "https://github.com/brentsimmons/NetNewsWire/blob/master/Technotes/HowToSupportNetNewsWire.markdown"
			}) {
				Text("How To Support NetNewsWire")
			}

			if !AccountManager.shared.anyAccountHasFeedWithURL("https://nnw.ranchero.com/feed.json") {
				Button(action: {
					self.viewController?.dismiss(animated: true) {
						let feedName = NSLocalizedString("NetNewsWire News", comment: "NetNewsWire News")
						self.coordinator?.showAdd(.feed, initialFeed: "https://nnw.ranchero.com/feed.json", initialFeedName: feedName)
					}
				}) {
					Text("Add NetNewsWire News Feed")
				}
			}
			
		}.sheet(isPresented: $isWebsitePresented) {
			SafariView(url: URL(string: self.website!)!)
		}
	}
	
	func buildSubscriptionsImportAccounts() -> ActionSheet {
		var buttons = [ActionSheet.Button]()
		
		for account in viewModel.activeAccounts {
			if account.behaviors.contains(.disallowOPMLImports) {
				continue
			}
			
			let button = ActionSheet.Button.default(Text(verbatim: account.nameForDisplay)) {
				self.opmlAccount = account
				self.isOPMLImportDocPickerPresented = true
			}
			
			buttons.append(button)
		}
		
		buttons.append(.cancel())
		return ActionSheet(title: Text("Import Subscriptions..."), message: Text("Select the account to import your OPML file into."), buttons: buttons)
	}
	
	func buildSubscriptionsExportAccounts() -> ActionSheet {
		var buttons = [ActionSheet.Button]()
		
		for account in viewModel.accounts {
			let button = ActionSheet.Button.default(Text(verbatim: account.nameForDisplay)) {
				self.opmlAccount = account
				self.isOPMLExportDocPickerPresented = true
			}
			buttons.append(button)
		}
		
		buttons.append(.cancel())
		return ActionSheet(title: Text("Export Subscriptions..."), message: Text("Select the account to export out of."), buttons: buttons)
	}
	
	func buildFooter() -> some View {
		return Text(verbatim: "\(Bundle.main.appName) v \(Bundle.main.versionNumber) (Build \(Bundle.main.buildNumber))")
			.font(.footnote)
			.foregroundColor(.secondary)
	}
	
	// MARK: ViewModel
	
	class ViewModel: ObservableObject {
		
		let objectWillChange = ObservableObjectPublisher()
		
		init() {
			NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .UserDidAddAccount, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .UserDidDeleteAccount, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		}
		
		var accounts: [Account] {
			get {
				return AccountManager.shared.sortedAccounts
			}
			set {
			}
		}
		
		var activeAccounts: [Account] {
			get {
				return AccountManager.shared.sortedActiveAccounts
			}
			set {
			}
		}
		
		var sortOldestToNewest: Bool {
			get {
				return AppDefaults.timelineSortDirection == .orderedDescending
			}
			set {
				objectWillChange.send()
				if newValue == true {
					AppDefaults.timelineSortDirection = .orderedDescending
				} else {
					AppDefaults.timelineSortDirection = .orderedAscending
				}
			}
		}
		
		var groupByFeed: Bool {
			get {
				return AppDefaults.timelineGroupByFeed
			}
			set {
				objectWillChange.send()
				AppDefaults.timelineGroupByFeed = newValue
			}
		}
		
		var timelineNumberOfLines: Int {
			get {
				return AppDefaults.timelineNumberOfLines
			}
			set {
				objectWillChange.send()
				AppDefaults.timelineNumberOfLines = newValue
			}
		}
		
		var refreshInterval: RefreshInterval {
			get {
				return AppDefaults.refreshInterval
			}
			set {
				objectWillChange.send()
				AppDefaults.refreshInterval = newValue
			}
		}
		
		@objc func accountsDidChange(_ notification: Notification) {
			objectWillChange.send()
		}
		
		@objc func displayNameDidChange(_ notification: Notification) {
			objectWillChange.send()
		}
		
	}

}

#if DEBUG
struct SettingsView_Previews : PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: SettingsView.ViewModel())
    }
}
#endif
