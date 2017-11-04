//
//  FeedListViewController.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/1/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import RSTree
import RSCore

final class FeedListViewController: NSViewController {

	@IBOutlet var outlineView: NSOutlineView!
	private let treeControllerDelegate = FeedListTreeControllerDelegate()
	lazy var treeController: TreeController = {
		TreeController(delegate: treeControllerDelegate)
	}()

}

// MARK: - NSOutlineViewDataSource

extension FeedListViewController: NSOutlineViewDataSource {

	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		
		return nodeForItem(item as AnyObject?).numberOfChildNodes
	}

	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {

		return nodeForItem(item as AnyObject?).childNodes![index]
	}

	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {

		return nodeForItem(item as AnyObject?).canHaveChildNodes
	}

	private func nodeForItem(_ item: AnyObject?) -> Node {

		if item == nil {
			return treeController.rootNode
		}
		return item as! Node
	}
}

// MARK: - NSOutlineViewDelegate

extension FeedListViewController: NSOutlineViewDelegate {

	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {

		let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "FeedListCell"), owner: self) as! SidebarCell

		let node = item as! Node
		configure(cell, node)

		return cell
	}

	func outlineViewSelectionDidChange(_ notification: Notification) {

//		// TODO: support multiple selection
//
//		let selectedRow = self.outlineView.selectedRow
//
//		if selectedRow < 0 || selectedRow == NSNotFound {
//			postSidebarSelectionDidChangeNotification(nil)
//			return
//		}
//
//		if let selectedNode = self.outlineView.item(atRow: selectedRow) as? Node {
//			postSidebarSelectionDidChangeNotification([selectedNode.representedObject])
//		}
	}

	private func configure(_ cell: SidebarCell, _ node: Node) {

		cell.objectValue = node
		cell.name = nameFor(node)
		cell.image = imageFor(node)
	}

	func imageFor(_ node: Node) -> NSImage? {

		return nil
	}

	func nameFor(_ node: Node) -> String {

		if let displayNameProvider = node.representedObject as? DisplayNameProvider {
			return displayNameProvider.nameForDisplay
		}
		return ""
	}

}
