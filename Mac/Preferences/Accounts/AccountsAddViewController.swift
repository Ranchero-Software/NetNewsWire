//
//  AccountsAddViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/1/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSCore

class AccountsAddViewController: NSViewController {
	
	@IBOutlet weak var tableView: NSTableView!
	
	private var accountsAddWindowController: NSWindowController?
	
	#if DEBUG
	private var addableAccountTypes: [AccountType] = [.onMyMac, .cloudKit, .bazQux, .feedbin, .feedly, .feedWrangler, .inoreader, .newsBlur, .theOldReader, .freshRSS]
	#else
	private var addableAccountTypes: [AccountType] = [.onMyMac, .cloudKit, .bazQux, .feedbin, .feedly, .feedWrangler, .inoreader, .newsBlur, .theOldReader, .freshRSS]
	#endif
	
	init() {
		super.init(nibName: "AccountsAdd", bundle: nil)
	}
	
	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.dataSource = self
		tableView.delegate = self
		restrictAccounts()
	}
	
}

// MARK: - NSTableViewDataSource

extension AccountsAddViewController: NSTableViewDataSource {
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return addableAccountTypes.count
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return nil
	}
}

// MARK: - NSTableViewDelegate

extension AccountsAddViewController: NSTableViewDelegate {
	
	private static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "AccountCell")
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		
		if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"), owner: nil) as? AccountsAddTableCellView {
			
			cell.accountType = addableAccountTypes[row]
			cell.delegate = self
			
			switch addableAccountTypes[row] {
			case .onMyMac:
				cell.accountNameLabel?.stringValue = Account.defaultLocalAccountName
				cell.accountImageView?.image = AppAssets.accountLocal
			case .cloudKit:
				cell.accountNameLabel?.stringValue = NSLocalizedString("iCloud", comment: "iCloud")
				cell.accountImageView?.image = AppAssets.accountCloudKit
			case .feedbin:
				cell.accountNameLabel?.stringValue = NSLocalizedString("Feedbin", comment: "Feedbin")
				cell.accountImageView?.image = AppAssets.accountFeedbin
			case .feedWrangler:
				cell.accountNameLabel?.stringValue = NSLocalizedString("Feed Wrangler", comment: "Feed Wrangler")
				cell.accountImageView?.image = AppAssets.accountFeedWrangler
			case .freshRSS:
				cell.accountNameLabel?.stringValue = NSLocalizedString("FreshRSS", comment: "FreshRSS")
				cell.accountImageView?.image = AppAssets.accountFreshRSS
			case .feedly:
				cell.accountNameLabel?.stringValue = NSLocalizedString("Feedly", comment: "Feedly")
				cell.accountImageView?.image = AppAssets.accountFeedly
			case .newsBlur:
				cell.accountNameLabel?.stringValue = NSLocalizedString("NewsBlur", comment: "NewsBlur")
				cell.accountImageView?.image = AppAssets.accountNewsBlur
			case .inoreader:
				cell.accountNameLabel?.stringValue = NSLocalizedString("Inoreader", comment: "Inoreader")
				cell.accountImageView?.image = AppAssets.accountInoreader
			case .bazQux:
				cell.accountNameLabel?.stringValue = NSLocalizedString("Bazqux", comment: "Bazqux")
				cell.accountImageView?.image = AppAssets.accountBazQux
			case .theOldReader:
				cell.accountNameLabel?.stringValue = NSLocalizedString("The Old Reader", comment: "The Old Reader")
				cell.accountImageView?.image = AppAssets.accountTheOldReader
			}
			return cell
		}
		return nil
	}
		
}

// MARK: AccountsAddTableCellViewDelegate

extension AccountsAddViewController: AccountsAddTableCellViewDelegate {
	
	func addAccount(_ accountType: AccountType) {
		
		switch accountType {
		case .onMyMac:
			let accountsAddLocalWindowController = AccountsAddLocalWindowController()
			accountsAddLocalWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsAddLocalWindowController
			
		case .cloudKit:
			let accountsAddCloudKitWindowController = AccountsAddCloudKitWindowController()
			accountsAddCloudKitWindowController.runSheetOnWindow(self.view.window!) { response in
				if response == NSApplication.ModalResponse.OK {
					self.restrictAccounts()
					self.tableView.reloadData()
				}
			}
			accountsAddWindowController = accountsAddCloudKitWindowController
			
		case .feedbin:
			let accountsFeedbinWindowController = AccountsFeedbinWindowController()
			accountsFeedbinWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsFeedbinWindowController
			
		case .feedWrangler:
			let accountsFeedWranglerWindowController = AccountsFeedWranglerWindowController()
			accountsFeedWranglerWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsFeedWranglerWindowController
			
		case .freshRSS:
			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
			accountsReaderAPIWindowController.accountType = .freshRSS
			accountsReaderAPIWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsReaderAPIWindowController
			
		case .feedly:
			let addAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
			addAccount.delegate = self
			addAccount.presentationAnchor = self.view.window!
			runAwaitingFeedlyLoginAlertModal(forLifetimeOf: addAccount)
			MainThreadOperationQueue.shared.add(addAccount)
			
		case .newsBlur:
			let accountsNewsBlurWindowController = AccountsNewsBlurWindowController()
			accountsNewsBlurWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsNewsBlurWindowController

		case .inoreader:
			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
			accountsReaderAPIWindowController.accountType = .inoreader
			accountsReaderAPIWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsReaderAPIWindowController
			
		case .bazQux:
			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
			accountsReaderAPIWindowController.accountType = .bazQux
			accountsReaderAPIWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsReaderAPIWindowController
			
		case .theOldReader:
			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
			accountsReaderAPIWindowController.accountType = .theOldReader
			accountsReaderAPIWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsReaderAPIWindowController
			
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

// MARK: OAuthAccountAuthorizationOperationDelegate

extension AccountsAddViewController: OAuthAccountAuthorizationOperationDelegate {
	
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

// MARK: Private

private extension AccountsAddViewController {
	
	func restrictAccounts() {
		func removeAccountType(_ accountType: AccountType) {
			if let index = addableAccountTypes.firstIndex(of: accountType) {
				addableAccountTypes.remove(at: index)
			}
		}
		
		if AppDefaults.shared.isDeveloperBuild {
			removeAccountType(.cloudKit)
			removeAccountType(.feedly)
			removeAccountType(.feedWrangler)
			return
		}

		if AccountManager.shared.accounts.firstIndex(where: { $0.type == .cloudKit }) != nil {
			removeAccountType(.cloudKit)
		}
	}
	
}
