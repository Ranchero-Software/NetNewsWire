//
//  ExtensionsPreferencesViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit

final class ExtensionPointPreferencesViewController: NSViewController {

	@IBOutlet weak var tableView: NSTableView!
	@IBOutlet weak var detailView: NSView!
	@IBOutlet weak var deleteButton: NSButton!
	
	private var sortedAccounts = [String]()

	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.delegate = self
		tableView.dataSource = self
		
		showController(ExtensionPointAddViewController())

		// Fix tableView frame — for some reason IB wants it 1pt wider than the clip view. This leads to unwanted horizontal scrolling.
		var rTable = tableView.frame
		rTable.size.width = tableView.superview!.frame.size.width
		tableView.frame = rTable
	}
	
}

// MARK: - NSTableViewDataSource

extension ExtensionPointPreferencesViewController: NSTableViewDataSource {

	func numberOfRows(in tableView: NSTableView) -> Int {
		return sortedAccounts.count
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return sortedAccounts[row]
	}
}

// MARK: - NSTableViewDelegate

extension ExtensionPointPreferencesViewController: NSTableViewDelegate {

	private static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "AccountCell")

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"), owner: nil) as? NSTableCellView {
			let account = sortedAccounts[row]
//			cell.textField?.stringValue = account.nameForDisplay
//			cell.imageView?.image = account.smallIcon?.image
			return cell
		}
		return nil
	}

	func tableViewSelectionDidChange(_ notification: Notification) {
		
		
	}
	
}

// MARK: - Private

private extension ExtensionPointPreferencesViewController {
	
	func showController(_ controller: NSViewController) {
		
		if let controller = children.first {
			children.removeAll()
			controller.view.removeFromSuperview()
		}
		
		addChild(controller)
		controller.view.translatesAutoresizingMaskIntoConstraints = false
		detailView.addSubview(controller.view)
		detailView.addFullSizeConstraints(forSubview: controller.view)
		
	}
	
}
