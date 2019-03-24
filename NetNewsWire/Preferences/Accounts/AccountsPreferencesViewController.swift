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

	private var sortedAccounts = [Account]()

	override func viewWillAppear() {
		updateSortedAccounts()
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

		func configure(_ cell: AccountsTableCellView) {
		}

		if let cell = tableView.makeView(withIdentifier: AccountsPreferencesViewController.cellIdentifier, owner: nil) as? AccountsTableCellView {
			configure(cell)
			return cell
		}

		let cell = AccountsTableCellView()
		cell.identifier = AccountsPreferencesViewController.cellIdentifier
		configure(cell)
		return cell
	}

	func tableViewSelectionDidChange(_ notification: Notification) {
	}
}

// MARK: - Private

private extension AccountsPreferencesViewController {

	func updateSortedAccounts() {
		sortedAccounts = AccountManager.shared.sortedAccounts
	}
}
