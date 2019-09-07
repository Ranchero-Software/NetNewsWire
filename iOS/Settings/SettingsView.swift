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
	
	@State var isWebsitePresented: Bool = false
	@State var isGithubRepoPresented: Bool = false
	@State var isBugTrackerPresented: Bool = false
	@State var isTechnotesPresented: Bool = false
	@State var isHowToSupportPresented: Bool = false

    var body: some View {
		NavigationView {
			Form {
				
//				Section(header: Text("ACCOUNTS")) {
//					ForEach(viewModel.accounts.identified(by: \.self)) { account in
//						NavigationLink(destination: SettingsDetailAccountView(viewModel: SettingsDetailAccountView.ViewModel(account)), isDetail: false) {
//							Text(verbatim: account.nameForDisplay)
//						}
//					}
//					NavigationLink(destination: SettingsAddAccountView(), isDetail: false) {
//						Text("Add Account")
//					}
//				}
				
				Section(header: Text("TIMELINE")) {
					Toggle(isOn: $viewModel.sortOldestToNewest) {
						Text("Sort Oldest to Newest")
					}
					Stepper(value: $viewModel.timelineNumberOfLines, in: 2...6) {
						Text("Number of Text Lines: \(viewModel.timelineNumberOfLines)")
					}
				}
				
//				Section(header: Text("DATABASE")) {
//					Picker(selection: $viewModel.refreshInterval, label: Text("Refresh Interval")) {
//						ForEach(RefreshInterval.allCases.identified(by: \.self)) { interval in
//							Text(interval.description()).tag(interval)
//						}
//					}
//					Button(action: {
//						self.subscriptionsImportAccounts = self.createSubscriptionsImportAccounts
//					}) {
//						Text("Import Subscriptions...")
//					}
//						.presentation(subscriptionsImportAccounts)
//						.presentation(subscriptionsImportDocumentPicker)
//					Button(action: {
//						self.subscriptionsExportAccounts = self.createSubscriptionsExportAccounts
//					}) {
//						Text("Export Subscriptions...")
//					}
//						.presentation(subscriptionsExportAccounts)
//						.presentation(subscriptionsExportDocumentPicker)
//				}
//				.foregroundColor(.primary)

				Section(header: Text("ABOUT"), footer: buildFooter) {
					Text("About NetNewsWire")
					
					Button(action: { self.isWebsitePresented.toggle() }) {
						Text("Website")
						}
					}.sheet(isPresented: $isWebsitePresented) {
						SafariView(url: URL(string: "https://ranchero.com/netnewswire/")!)
					}
					
					VStack {
						Button(action: { self.isGithubRepoPresented.toggle() }) {
							Text("Github Repository")
						}
					}.sheet(isPresented: $isGithubRepoPresented) {
						SafariView(url: URL(string: "https://github.com/brentsimmons/NetNewsWire")!)
					}
					
					VStack {
						Button(action: { self.isBugTrackerPresented.toggle() }) {
							Text("Bug Tracker")
						}
					}.sheet(isPresented: $isBugTrackerPresented) {
						SafariView(url: URL(string: "https://github.com/brentsimmons/NetNewsWire/issues")!)
					}
					
					VStack {
						Button(action: { self.isTechnotesPresented.toggle() }) {
							Text("Technotes")
						}
					}.sheet(isPresented: $isTechnotesPresented) {
						SafariView(url: URL(string: "https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes")!)
					}
					
					VStack {
						Button(action: { self.isHowToSupportPresented.toggle() }) {
							Text("Technotes")
						}
					}.sheet(isPresented: $isHowToSupportPresented) {
						SafariView(url: URL(string: "hhttps://github.com/brentsimmons/NetNewsWire/blob/master/Technotes/HowToSupportNetNewsWire.markdown")!)
					}

					Text("Add NetNewsWire News Feed")
					
				}
				.foregroundColor(.primary)
				
			}
			.navigationBarTitle(Text("Settings"), displayMode: .inline)
		}
    }
	
//	var createSubscriptionsImportAccounts: ActionSheet {
//		var buttons = [ActionSheet.Button]()
//		
//		for account in viewModel.activeAccounts {
//			if !account.isOPMLImportSupported {
//				continue
//			}
//			
//			let button = ActionSheet.Button.default(Text(verbatim: account.nameForDisplay)) {
//				self.subscriptionsImportAccounts = nil
//				self.subscriptionsImportDocumentPicker = Modal(SettingsSubscriptionsImportDocumentPickerView(account: account))
//			}
//			
//			buttons.append(button)
//		}
//		
//		buttons.append(.cancel { self.subscriptionsImportAccounts = nil })
//		return ActionSheet(title: Text("Import Subscriptions..."), message: Text("Select the account to import your OPML file into."), buttons: buttons)
//	}
//	
//	var createSubscriptionsExportAccounts: ActionSheet {
//		var buttons = [ActionSheet.Button]()
//		
//		for account in viewModel.accounts {
//			let button = ActionSheet.Button.default(Text(verbatim: account.nameForDisplay)) {
//				self.subscriptionsExportAccounts = nil
//				self.subscriptionsExportDocumentPicker = Modal(SettingsSubscriptionsExportDocumentPickerView(account: account))
//			}
//			buttons.append(button)
//		}
//		
//		buttons.append(.cancel { self.subscriptionsExportAccounts = nil })
//		return ActionSheet(title: Text("Export Subscriptions..."), message: Text("Select the account to export out of."), buttons: buttons)
//	}
	
	var buildFooter: some View {
		return Text(verbatim: "\(Bundle.main.appName) v \(Bundle.main.versionNumber) (Build \(Bundle.main.buildNumber))")
			.font(.footnote)
			.foregroundColor(.secondary)
	}
	
	// MARK: ViewModel
	
	class ViewModel: ObservableObject {
		
		let objectWillChange = ObservableObjectPublisher()
		
		init() {
			NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .AccountsDidChange, object: nil)
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
