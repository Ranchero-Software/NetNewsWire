//
//  SidebarOutlineDataSource.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/12/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSTree
import Articles
import RSCore
import Account

@objc final class SidebarOutlineDataSource: NSObject, NSOutlineViewDataSource {

	let treeController: TreeController
	static let dragOperationNone = NSDragOperation(rawValue: 0)

	init(treeController: TreeController) {
		self.treeController = treeController
	}

	// MARK: - NSOutlineViewDataSource

	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {

		return nodeForItem(item as AnyObject?).numberOfChildNodes
	}

	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {

		return nodeForItem(item as AnyObject?).childNodes[index]
	}

	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {

		return nodeForItem(item as AnyObject?).canHaveChildNodes
	}

	func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
		let node = nodeForItem(item as AnyObject?)
		guard nodeRepresentsDraggableItem(node) else {
			return nil
		}
		return (node.representedObject as? PasteboardWriterOwner)?.pasteboardWriter
	}

	// MARK: - Drag and Drop

	func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
		let draggingSourceOutlineView = info.draggingSource() as? NSOutlineView
		let isLocalDrop = draggingSourceOutlineView == outlineView
		if isLocalDrop {
			return validateLocalDrop(info, proposedItem: item, proposedChildIndex: index)
		}
		return SidebarOutlineDataSource.dragOperationNone
	}

	func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
		return false
	}
}

// MARK: - Private

private extension SidebarOutlineDataSource {

	func nodeForItem(_ item: AnyObject?) -> Node {

		if item == nil {
			return treeController.rootNode
		}
		return item as! Node
	}

	func nodeRepresentsDraggableItem(_ node: Node) -> Bool {
		// Don’t allow PseudoFeed or Folder to be dragged.
		// This will have to be revisited later. For instance,
		// user-created smart feeds should be draggable, maybe.
		// And we might allow dragging folders between accounts.
		return node.representedObject is Feed
	}

	func validateLocalDrop(_ info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {

//		let node = nodeForItem(item)
		return SidebarOutlineDataSource.dragOperationNone

	}
}
