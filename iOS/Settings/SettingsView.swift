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
	@State var subscriptionsImportAccounts: ActionSheet? = nil
	@State var subscriptionsImportDocumentPicker: Modal? = nil
	@State var subscriptionsExportAccounts: ActionSheet? = nil
	@State var subscriptionsExportDocumentPicker: Modal? = nil

    var body: some View {
		NavigationView {
			Form {
				
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
						self.subscriptionsImportAccounts = self.createSubscriptionsImportAccounts
					}) {
						Text("Import Subscriptions...")
					}
						.presentation(subscriptionsImportAccounts)
						.presentation(subscriptionsImportDocumentPicker)
					Button(action: {
						self.subscriptionsExportAccounts = self.createSubscriptionsExportAccounts
					}) {
						Text("Export Subscriptions...")
					}
						.presentation(subscriptionsExportAccounts)
						.presentation(subscriptionsExportDocumentPicker)
				}
				.foregroundColor(.primary)

				Section(header: Text("ABOUT"), footer: buildFooter) {
					Text("About NetNewsWire")
					PresentationButton(destination: SafariView(url: URL(string: "https://ranchero.com/netnewswire/")!)) {
						Text("Website")
					}
					PresentationButton(destination: SafariView(url: URL(string: "https://github.com/brentsimmons/NetNewsWire")!)) {
						Text("Github Repository")
					}
					PresentationButton(destination: SafariView(url: URL(string: "https://github.com/brentsimmons/NetNewsWire/issues")!)) {
						Text("Bug Tracker")
					}
					PresentationButton(destination: SafariView(url: URL(string: "https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes")!)) {
						Text("Technotes")
					}
					PresentationButton(destination: SafariView(url: URL(string: "https://github.com/brentsimmons/NetNewsWire/blob/master/Technotes/HowToSupportNetNewsWire.markdown")!)) {
						Text("How to Support NetNewsWire")
					}
					Text("Add NetNewsWire News Feed")
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
				self.subscriptionsImportAccounts = nil
				self.subscriptionsImportDocumentPicker = Modal(SettingsSubscriptionsImportDocumentPickerView(account: account))
			}
			
			buttons.append(button)
		}
		
		buttons.append(.cancel { self.subscriptionsImportAccounts = nil })
		return ActionSheet(title: Text("Import Subscriptions..."), message: Text("Select the account to import your OPML file into."), buttons: buttons)
	}
	
	var createSubscriptionsExportAccounts: ActionSheet {
		var buttons = [ActionSheet.Button]()
		
		for account in viewModel.accounts {
			let button = ActionSheet.Button.default(Text(verbatim: account.nameForDisplay)) {
				self.subscriptionsExportAccounts = nil
				self.subscriptionsExportDocumentPicker = Modal(SettingsSubscriptionsExportDocumentPickerView(account: account))
			}
			buttons.append(button)
		}
		
		buttons.append(.cancel { self.subscriptionsExportAccounts = nil })
		return ActionSheet(title: Text("Export Subscriptions..."), message: Text("Select the account to export out of."), buttons: buttons)
	}
	
	var buildFooter: some View {
		return Text(verbatim: "\(Bundle.main.appName) v \(Bundle.main.versionNumber) (Build \(Bundle.main.buildNumber))")
			.font(.footnote)
			.foregroundColor(.secondary)
	}
	
	// MARK: ViewModel
	
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
