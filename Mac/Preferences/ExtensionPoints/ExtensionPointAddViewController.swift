//
//  ExtensionPointAddViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit

class ExtensionPointAddViewController: NSViewController {

	@IBOutlet weak var tableView: NSTableView!
	
	private var availableExtensionPointTypes = [ExtensionPoint.Type]()
	private var extensionPointAddWindowController: NSWindowController?

	init() {
		super.init(nibName: "ExtensionPointAdd", bundle: nil)
	}
	
	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	override func viewDidLoad() {
        super.viewDidLoad()
		tableView.dataSource = self
		tableView.delegate = self
		availableExtensionPointTypes = ExtensionPointManager.shared.availableExtensionPointTypes.sorted(by: { $0.title < $1.title })
    }
    
}

// MARK: - NSTableViewDataSource

extension ExtensionPointAddViewController: NSTableViewDataSource {
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return availableExtensionPointTypes.count
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return nil
	}
}

// MARK: - NSTableViewDelegate

extension ExtensionPointAddViewController: NSTableViewDelegate {
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		
		if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"), owner: nil) as? ExtensionPointAddTableCellView {
			let extensionPointType = availableExtensionPointTypes[row]
			cell.titleLabel?.stringValue = extensionPointType.title
			cell.imageView?.image = extensionPointType.templateImage
			return cell
		}
		return nil
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		let selectedRow = tableView.selectedRow
		guard selectedRow != -1 else {
			return
		}

		let extensionPointType = availableExtensionPointTypes[selectedRow]

		let windowController = ExtensionPointEnableWindowController()
		windowController.extensionPointType = extensionPointType
		windowController.runSheetOnWindow(self.view.window!)
		extensionPointAddWindowController = windowController
		
		tableView.selectRowIndexes([], byExtendingSelection: false)
	}
	
}
