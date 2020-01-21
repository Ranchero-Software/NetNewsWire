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
	
	private let addableAccountTypes: [AccountType] = [.onMyMac, .feedbin, .feedly, .feedWrangler, .freshRSS]
	
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
			switch addableAccountTypes[row] {
			case .onMyMac:
				cell.accountNameLabel?.stringValue = Account.defaultLocalAccountName
				cell.accountImageView?.image = AppAssets.accountLocal
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
			default:
				break
			}
			return cell
		}
		return nil
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		
		let selectedRow = tableView.selectedRow
		guard selectedRow != -1 else {
			return
		}

		switch addableAccountTypes[selectedRow] {
		case .onMyMac:
			let accountsAddLocalWindowController = AccountsAddLocalWindowController()
			accountsAddLocalWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsAddLocalWindowController
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
			MainThreadOperationQueue.shared.addOperation(addAccount)
		default:
			break
		}
		
		tableView.selectRowIndexes([], byExtendingSelection: false)
		
	}
	
}

// MARK: OAuthAccountAuthorizationOperationDelegate

extension AccountsAddViewController: OAuthAccountAuthorizationOperationDelegate {
	
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account) {
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
		view.window?.presentError(error)
	}
}
