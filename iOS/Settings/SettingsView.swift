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
	@ObjectBinding var viewModel: ViewModel
	@State var showImportSubscriptions = false
	@State var showExportSubscriptions = false

    var body: some View {
		NavigationView {
			List {
				
				Section(header: Text("ACCOUNTS")) {
					ForEach(viewModel.accounts.identified(by: \.self)) { account in
						NavigationButton(destination: SettingsDetailAccountView(viewModel: SettingsDetailAccountView.ViewModel(account)), isDetail: false) {
							Text(verbatim: account.nameForDisplay)
						}
					}
					NavigationButton(destination: SettingsAddAccountView(), isDetail: false) {
						Text("Add Account")
					}
				}
				
				Section(header: Text("ABOUT")) {
					
					Text("About NetNewsWire")

					Button(action: {
						UIApplication.shared.open(URL(string: "https://ranchero.com/netnewswire/")!, options: [:])
					}) {
						Text("Website")
					}
					
					Button(action: {
						UIApplication.shared.open(URL(string: "https://github.com/brentsimmons/NetNewsWire")!, options: [:])
					}) {
						Text("Github Repository")
					}

					Button(action: {
						UIApplication.shared.open(URL(string: "https://github.com/brentsimmons/NetNewsWire/issues")!, options: [:])
					}) {
						Text("Bug Tracker")
					}

					Button(action: {
						UIApplication.shared.open(URL(string: "https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes")!, options: [:])
					}) {
						Text("Technotes")
					}

					Text("Add NetNewsWire News Feed")
					
				}
				.foregroundColor(.primary)
				
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
						ForEach(RefreshInterval.allCases.identified(by: \.self)) { interval in
							Text(interval.description()).tag(interval)
						}
					}
					Button(action: {
						self.showImportSubscriptions = true
					}) {
						Text("Import Subscriptions...")
					}
					.presentation(showImportSubscriptions ? importSubscriptionsActionSheet : nil)
					Button(action: {
						self.showExportSubscriptions = true
					}) {
						Text("Export Subscriptions...")
					}
					.presentation(showExportSubscriptions ? exportSubscriptionsActionSheet : nil)
				}
				.foregroundColor(.primary)

			}
			.listStyle(.grouped)
			.navigationBarTitle(Text("Settings"), displayMode: .inline)

		}
    }
	
	var importSubscriptionsActionSheet: ActionSheet {
		var buttons = [ActionSheet.Button]()
		for account in viewModel.accounts {
			let button = ActionSheet.Button.default(Text(verbatim: account.nameForDisplay)) {
				self.showImportSubscriptions = false
				// Call doc picker here...
			}
			buttons.append(button)
		}
		buttons.append(.cancel { self.showImportSubscriptions = false })
		return ActionSheet(title: Text("Import Subscriptions..."), message: Text("Select the account to import your OPML file into."), buttons: buttons)
	}
	
	var exportSubscriptionsActionSheet: ActionSheet {
		var buttons = [ActionSheet.Button]()
		for account in viewModel.accounts {
			let button = ActionSheet.Button.default(Text(verbatim: account.nameForDisplay)) {
				self.showExportSubscriptions = false
				// Call doc picker here...
			}
			buttons.append(button)
		}
		buttons.append(.cancel { self.showImportSubscriptions = false })
		return ActionSheet(title: Text("Export Subscriptions..."), message: Text("Select the account to export out of."), buttons: buttons)
	}
	
	class ViewModel: BindableObject {
		
		let didChange = PassthroughSubject<ViewModel, Never>()
		
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
		
		var sortOldestToNewest: Bool {
			get {
				return AppDefaults.timelineSortDirection == .orderedDescending
			}
			set {
				if newValue == true {
					AppDefaults.timelineSortDirection = .orderedDescending
				} else {
					AppDefaults.timelineSortDirection = .orderedAscending
				}
				didChange.send(self)
			}
		}
		
		var timelineNumberOfLines: Int {
			get {
				return AppDefaults.timelineNumberOfLines
			}
			set {
				AppDefaults.timelineNumberOfLines = newValue
				didChange.send(self)
			}
		}
		
		var refreshInterval: RefreshInterval {
			get {
				return AppDefaults.refreshInterval
			}
			set {
				AppDefaults.refreshInterval = newValue
				didChange.send(self)
			}
		}
		
		@objc func accountsDidChange(_ notification: Notification) {
			didChange.send(self)
		}
		
		@objc func displayNameDidChange(_ notification: Notification) {
			didChange.send(self)
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
