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

@objc final class SidebarOutlineDataSource: NSObject, NSOutlineViewDataSource {

	let treeController: TreeController

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
		return (node.representedObject as? PasteboardWriterOwner)?.pasteboardWriter
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
}
