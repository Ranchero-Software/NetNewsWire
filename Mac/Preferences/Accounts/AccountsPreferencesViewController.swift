//
//  AccountsPreferencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/17/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import SwiftUI
import RSCore

// MARK: - AccountsPreferencesAddAccountDelegate
protocol AccountsPreferencesAddAccountDelegate {
	func presentSheetForAccount(_ accountType: AccountType)
}

// MARK: - AccountsPreferencesViewController
final class AccountsPreferencesViewController: NSViewController {

	@IBOutlet weak var tableView: NSTableView!
	@IBOutlet weak var detailView: NSView!
	@IBOutlet weak var deleteButton: NSButton!
	var addAccountDelegate: AccountsPreferencesAddAccountDelegate?
	var addAccountWindowController: NSWindowController?
	
	private var sortedAccounts = [Account]()

	override func viewDidLoad() {
		super.viewDidLoad()

		updateSortedAccounts()
		tableView.delegate = self
		tableView.dataSource = self
		addAccountDelegate = self
		
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .UserDidDeleteAccount, object: nil)


		// Fix tableView frame — for some reason IB wants it 1pt wider than the clip view. This leads to unwanted horizontal scrolling.
		var rTable = tableView.frame
		rTable.size.width = tableView.superview!.frame.size.width
		tableView.frame = rTable
		
		// Set initial row selection
		if sortedAccounts.count > 0 {
			tableView.selectRow(0)
		}
	}
	
	@IBAction func addAccount(_ sender: Any) {
		let controller = NSHostingController(rootView: AddAccountsView(delegate: self))
		controller.rootView.parent = controller
		presentAsSheet(controller)
	}
	
	@IBAction func removeAccount(_ sender: Any) {
		
		guard tableView.selectedRow != -1 else {
			return
		}
		
		let acctName = sortedAccounts[tableView.selectedRow].nameForDisplay
		
		let alert = NSAlert()
		alert.alertStyle = .warning
		let deletePrompt = NSLocalizedString("Delete", comment: "Delete")
		alert.messageText = "\(deletePrompt) “\(acctName)”?"
		alert.informativeText = NSLocalizedString("Are you sure you want to delete the account “\(acctName)”? This cannot be undone.", comment: "Delete text")
		
		alert.addButton(withTitle: NSLocalizedString("Delete", comment: "Delete Account"))
		alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel Delete Account"))
			
		alert.beginSheetModal(for: view.window!) { [weak self] result in
			if result == NSApplication.ModalResponse.alertFirstButtonReturn {
				guard let self = self else { return }
				AccountManager.shared.deleteAccount(self.sortedAccounts[self.tableView.selectedRow])
			}
		}
		
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		updateSortedAccounts()
		tableView.reloadData()
	}
	
	@objc func accountsDidChange(_ note: Notification) {
		updateSortedAccounts()
		tableView.reloadData()
	}
	
}

// MARK: - NSTableViewDataSource

extension AccountsPreferencesViewController: NSTableViewDataSource {

	func numberOfRows(in tableView: NSTableView) -> Int {
		return sortedAccounts.count
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return sortedAccounts[row]
	}
}

// MARK: - NSTableViewDelegate

extension AccountsPreferencesViewController: NSTableViewDelegate {

	private static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "AccountCell")

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"), owner: nil) as? NSTableCellView {
			let account = sortedAccounts[row]
			cell.textField?.stringValue = account.nameForDisplay
			cell.imageView?.image = account.smallIcon?.image
			return cell
		}
		return nil
	}

	func tableViewSelectionDidChange(_ notification: Notification) {
		
		let selectedRow = tableView.selectedRow
		if tableView.selectedRow == -1 {
			deleteButton.isEnabled = false
			hideController()
			return
		} else {
			deleteButton.isEnabled = true
		}

		let account = sortedAccounts[selectedRow]
		if AccountManager.shared.defaultAccount == account {
			deleteButton.isEnabled = false
		}
		
		let controller = AccountsDetailViewController(account: account)
		showController(controller)
		
	}
	
}

extension AccountsPreferencesViewController: AccountsPreferencesAddAccountDelegate {
	func presentSheetForAccount(_ accountType: AccountType) {
		switch accountType {
		case .onMyMac:
			let accountsAddLocalWindowController = AccountsAddLocalWindowController()
			accountsAddLocalWindowController.runSheetOnWindow(self.view.window!)
			addAccountWindowController = accountsAddLocalWindowController
		case .cloudKit:
			let accountsAddCloudKitWindowController = AccountsAddCloudKitWindowController()
			accountsAddCloudKitWindowController.runSheetOnWindow(self.view.window!) { response in
				if response == NSApplication.ModalResponse.OK {
					self.tableView.reloadData()
				}
			}
			addAccountWindowController = accountsAddCloudKitWindowController
		case .feedbin:
			let accountsFeedbinWindowController = AccountsFeedbinWindowController()
			accountsFeedbinWindowController.runSheetOnWindow(self.view.window!)
			addAccountWindowController = accountsFeedbinWindowController
		case .feedWrangler:
			let accountsFeedWranglerWindowController = AccountsFeedWranglerWindowController()
			accountsFeedWranglerWindowController.runSheetOnWindow(self.view.window!)
			addAccountWindowController = accountsFeedWranglerWindowController
		case .freshRSS, .inoreader, .bazQux, .theOldReader:
			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
			accountsReaderAPIWindowController.accountType = accountType
			accountsReaderAPIWindowController.runSheetOnWindow(self.view.window!)
			addAccountWindowController = accountsReaderAPIWindowController
		case .feedly:
			let addAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
			addAccount.delegate = self
			addAccount.presentationAnchor = self.view.window!
			runAwaitingFeedlyLoginAlertModal(forLifetimeOf: addAccount)
			MainThreadOperationQueue.shared.add(addAccount)
		case .newsBlur:
			let accountsNewsBlurWindowController = AccountsNewsBlurWindowController()
			accountsNewsBlurWindowController.runSheetOnWindow(self.view.window!)
			addAccountWindowController = accountsNewsBlurWindowController
		}
	}
	
	private func runAwaitingFeedlyLoginAlertModal(forLifetimeOf operation: OAuthAccountAuthorizationOperation) {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = NSLocalizedString("Waiting for access to Feedly",
											  comment: "Alert title when adding a Feedly account and waiting for authorization from the user.")
		
		alert.informativeText = NSLocalizedString("Your default web browser will open the Feedly login for you to authorize access.",
												  comment: "Alert informative text when adding a Feedly account and waiting for authorization from the user.")
		
		alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel"))
		
		let attachedWindow = self.view.window!
		
		alert.beginSheetModal(for: attachedWindow) { response in
			if response == .alertFirstButtonReturn {
				operation.cancel()
			}
		}
		
		operation.completionBlock = { _ in
			guard alert.window.isVisible else {
				return
			}
			attachedWindow.endSheet(alert.window)
		}
	}
}

// MARK: - Private

private extension AccountsPreferencesViewController {

	func updateSortedAccounts() {
		sortedAccounts = AccountManager.shared.sortedAccounts
	}
	
	func showController(_ controller: NSViewController) {
		hideController()
		
		addChild(controller)
		controller.view.translatesAutoresizingMaskIntoConstraints = false
		detailView.addSubview(controller.view)
		detailView.addFullSizeConstraints(forSubview: controller.view)
		
	}
	
	func hideController() {
		if let controller = children.first {
			children.removeAll()
			controller.view.removeFromSuperview()
		}
	}
	
}

extension AccountsPreferencesViewController: OAuthAccountAuthorizationOperationDelegate {
	
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account) {
		// `OAuthAccountAuthorizationOperation` is using `ASWebAuthenticationSession` which bounces the user
		// to their browser on macOS for authorizing NetNewsWire to access the user's Feedly account.
		// When this authorization is granted, the browser remains the foreground app which is unfortunate
		// because the user probably wants to see the result of authorizing NetNewsWire to act on their behalf.
		NSApp.activate(ignoringOtherApps: true)
		
		account.refreshAll { [weak self] result in
			switch result {
			case .success:
				break
			case .failure(let error):
				self?.presentError(error)
			}
		}
	}
	
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error) {
		// `OAuthAccountAuthorizationOperation` is using `ASWebAuthenticationSession` which bounces the user
		// to their browser on macOS for authorizing NetNewsWire to access the user's Feedly account.
		NSApp.activate(ignoringOtherApps: true)
		
		view.window?.presentError(error)
	}
}
