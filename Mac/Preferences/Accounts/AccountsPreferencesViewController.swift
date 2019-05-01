//
//  AccountsPreferencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/17/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

final class AccountsPreferencesViewController: NSViewController {

	@IBOutlet weak var tableView: NSTableView!
	@IBOutlet weak var detailView: NSView!
	@IBOutlet weak var deleteButton: NSButton!
	
	private var deleteController: AccountsDeleteWindowController?
	private var sortedAccounts = [Account]()

	override func viewDidLoad() {
		super.viewDidLoad()

		updateSortedAccounts()
		tableView.delegate = self
		tableView.dataSource = self
		
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChangeNotification(_:)), name: .AccountsDidChangeNotification, object: nil)
		
		showController(AccountsAddViewController())

	}
	
	@IBAction func addAccount(_ sender: Any) {
		tableView.selectRowIndexes([], byExtendingSelection: false)
		showController(AccountsAddViewController())
	}
	
	@IBAction func removeAccount(_ sender: Any) {
		guard tableView.selectedRow != -1 else {
			return
		}
		let account = sortedAccounts[tableView.selectedRow]
		deleteController = AccountsDeleteWindowController(account: account)
		deleteController!.runSheetOnWindow(view.window!)
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		updateSortedAccounts()
		tableView.reloadData()
	}
	
	@objc func accountsDidChangeNotification(_ note: Notification) {
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
			switch account.type {
			case .onMyMac:
				cell.imageView?.image = AppImages.accountLocal
			case .feedbin:
				cell.imageView?.image = NSImage(named: "accountFeedbin")
			default:
				break
			}
			return cell
		}
		return nil
	}

	func tableViewSelectionDidChange(_ notification: Notification) {
		
		let selectedRow = tableView.selectedRow
		if tableView.selectedRow == -1 {
			deleteButton.isEnabled = false
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

// MARK: - Private

private extension AccountsPreferencesViewController {

	func updateSortedAccounts() {
		sortedAccounts = AccountManager.shared.sortedAccounts
	}
	
	func showController(_ controller: NSViewController) {
		
		if let controller = children.first {
			children.removeAll()
			controller.view.removeFromSuperview()
		}
		
		addChild(controller)
		controller.view.translatesAutoresizingMaskIntoConstraints = false
		detailView.addSubview(controller.view)
		detailView.rs_addFullSizeConstraints(forSubview: controller.view)
		
	}
	
}
