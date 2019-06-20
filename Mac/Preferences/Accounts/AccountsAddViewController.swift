//
//  AccountsAddViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/1/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

class AccountsAddViewController: NSViewController {
	
	@IBOutlet weak var tableView: NSTableView!
	
	private var accountsAddWindowController: NSWindowController?
	
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
		return 3
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
			switch row {
			case 0:
				cell.accountNameLabel?.stringValue = Account.defaultLocalAccountName
				cell.accountImageView?.image = AppAssets.accountLocal
			case 1:
				cell.accountNameLabel?.stringValue = NSLocalizedString("Feedbin", comment: "Feedbin")
				cell.accountImageView?.image = AppAssets.accountFeedbin
			case 2:
				cell.accountNameLabel?.stringValue = NSLocalizedString("FreshRSS", comment: "FreshRSS")
				cell.accountImageView?.image = AppAssets.accountFreshRSS
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

		switch selectedRow {
		case 0:
			let accountsAddLocalWindowController = AccountsAddLocalWindowController()
			accountsAddLocalWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsAddLocalWindowController
		case 1:
			let accountsFeedbinWindowController = AccountsFeedbinWindowController()
			accountsFeedbinWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsFeedbinWindowController
		case 2:
			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
			accountsReaderAPIWindowController.accountType = .freshRSS
			accountsReaderAPIWindowController.runSheetOnWindow(self.view.window!)
			accountsAddWindowController = accountsReaderAPIWindowController
		default:
			break
		}
		
		tableView.selectRowIndexes([], byExtendingSelection: false)
		
	}
	
}
