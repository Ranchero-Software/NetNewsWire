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
	@State var website: String? = nil
	
	@State var isOPMLImportPresented: Bool = false
	@State var isOPMLImportDocPickerPresented: Bool = false
	@State var isOPMLExportPresented: Bool = false
	@State var isOPMLExportDocPickerPresented: Bool = false
	@State var opmlAccount: Account? = nil

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
				
				Section(header: Text("DATABASE")) {
					Picker(selection: $viewModel.refreshInterval, label: Text("Refresh Interval")) {
						ForEach(RefreshInterval.allCases) { interval in
							Text(interval.description()).tag(interval)
						}
					}
					
					VStack {
						 Button("Import Subscriptions...") {
							 self.isOPMLImportPresented = true
						 }
					}.actionSheet(isPresented: $isOPMLImportPresented) {
						createSubscriptionsImportAccounts
					}.sheet(isPresented: $isOPMLImportDocPickerPresented) {
						SettingsSubscriptionsImportDocumentPickerView(account: self.opmlAccount!)
					}
					
					VStack {
						 Button("Export Subscriptions...") {
							 self.isOPMLExportPresented = true
						 }
					 }.actionSheet(isPresented: $isOPMLExportPresented) {
						createSubscriptionsExportAccounts
					 }.sheet(isPresented: $isOPMLExportDocPickerPresented) {
						 SettingsSubscriptionsExportDocumentPickerView(account: self.opmlAccount!)
					 }
				}
				.foregroundColor(.primary)

				Section(header: Text("ABOUT"), footer: buildFooter) {
					Text("About NetNewsWire")
					
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

					Text("Add NetNewsWire News Feed")
					
				}.sheet(isPresented: $isWebsitePresented) {
					SafariView(url: URL(string: self.website!)!)
				}
				.foregroundColor(.primary)
				
			}
			.navigationBarTitle(Text("Settings"), displayMode: .inline)
		}
    }
	
	var createSubscriptionsImportAccounts: ActionSheet {
		var buttons = [ActionSheet.Button]()
		
		for account in viewModel.activeAccounts {
			if !account.isOPMLImportSupported {
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
	
	var createSubscriptionsExportAccounts: ActionSheet {
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
