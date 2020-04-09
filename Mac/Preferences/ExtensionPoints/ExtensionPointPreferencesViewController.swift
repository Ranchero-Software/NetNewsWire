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
	
	private var activeExtensionPointIDs = [ExtensionPointIdentifer]()

	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.delegate = self
		tableView.dataSource = self

		NotificationCenter.default.addObserver(self, selector: #selector(activeExtensionPointsDidChange(_:)), name: .ActiveExtensionPointsDidChange, object: nil)

		showController(ExtensionPointAddViewController())

		// Fix tableView frame — for some reason IB wants it 1pt wider than the clip view. This leads to unwanted horizontal scrolling.
		var rTable = tableView.frame
		rTable.size.width = tableView.superview!.frame.size.width
		tableView.frame = rTable
		
		activeExtensionPointIDs = Array(ExtensionPointManager.shared.activeExtensionPoints.keys)
		tableView.reloadData()
	}
	
	@IBAction func enableExtensionPoints(_ sender: Any) {
		tableView.selectRowIndexes([], byExtendingSelection: false)
		showController(ExtensionPointAddViewController())
	}
	
	@IBAction func disableExtensionPoint(_ sender: Any) {
		guard tableView.selectedRow != -1 else {
			return
		}
		
		let extensionPointID = activeExtensionPointIDs[tableView.selectedRow]
		ExtensionPointManager.shared.deactivateExtensionPoint(extensionPointID)

		showController(ExtensionPointAddViewController())
	}
}

// MARK: - NSTableViewDataSource

extension ExtensionPointPreferencesViewController: NSTableViewDataSource {

	func numberOfRows(in tableView: NSTableView) -> Int {
		return activeExtensionPointIDs.count
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return activeExtensionPointIDs[row]
	}
}

// MARK: - NSTableViewDelegate

extension ExtensionPointPreferencesViewController: NSTableViewDelegate {

	private static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "AccountCell")

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"), owner: nil) as? NSTableCellView {
			let extensionPointID = activeExtensionPointIDs[row]
			cell.textField?.stringValue = extensionPointID.title
			cell.imageView?.image = extensionPointID.templateImage
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

		let extensionPointID = activeExtensionPointIDs[selectedRow]
		let controller = ExtensionPointDetailViewController(extensionPointID: extensionPointID)
		showController(controller)
		
	}
	
}

// MARK: - Private

private extension ExtensionPointPreferencesViewController {
	
	@objc func activeExtensionPointsDidChange(_ note: Notification) {
		activeExtensionPointIDs = Array(ExtensionPointManager.shared.activeExtensionPoints.keys).sorted(by: { $0.title < $1.title })
		tableView.reloadData()
		showController(ExtensionPointAddViewController())
	}
	
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
