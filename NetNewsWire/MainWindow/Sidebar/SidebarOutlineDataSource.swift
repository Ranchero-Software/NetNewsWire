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

		return nodeForItem(item).numberOfChildNodes
	}

	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {

		return nodeForItem(item).childNodes[index]
	}

	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {

		return nodeForItem(item).canHaveChildNodes
	}

	func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
		let node = nodeForItem(item)
		guard nodeRepresentsDraggableItem(node) else {
			return nil
		}
		return (node.representedObject as? PasteboardWriterOwner)?.pasteboardWriter
	}

	// MARK: - Drag and Drop

	func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
		let parentNode = nodeForItem(item)
		if parentNode == treeController.rootNode {
			return SidebarOutlineDataSource.dragOperationNone
		}

		guard let draggedFeeds = PasteboardFeed.pasteboardFeeds(with: info.draggingPasteboard()), !draggedFeeds.isEmpty else {
			return SidebarOutlineDataSource.dragOperationNone
		}

		let contentsType = draggedFeedContentsType(draggedFeeds)
		if contentsType == .empty || contentsType == .mixed || contentsType == .multipleNonLocal {
			return SidebarOutlineDataSource.dragOperationNone
		}

		if contentsType == .singleNonLocal {
			let draggedNonLocalFeed = singleNonLocalFeed(from: draggedFeeds)!
			return validateSingleNonLocalFeedDrop(outlineView, draggedNonLocalFeed, parentNode, index)
		}

//		let draggingSourceOutlineView = info.draggingSource() as? NSOutlineView
//		let isLocalDrop = draggingSourceOutlineView == outlineView

//		// If NSOutlineViewDropOnItemIndex, retarget to parent of parent item, if possible.
//		if index == NSOutlineViewDropOnItemIndex && !parentNode.canHaveChildNodes {
//			guard let grandparentNode = parentNode.parent, grandparentNode.canHaveChildNodes else {
//				return SidebarOutlineDataSource.dragOperationNone
//			}
//			outlineView.setDropItem(grandparentNode, dropChildIndex: NSOutlineViewDropOnItemIndex)
//			return isLocalDrop ? .move : .copy
//		}

//		if isLocalDrop {
//			return validateLocalDrop(draggedFeeds, parentNode: parentNode, proposedChildIndex: index)
//		}
		return SidebarOutlineDataSource.dragOperationNone
	}

	func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
		return false
	}
}

// MARK: - Private

private extension SidebarOutlineDataSource {

	func nodeForItem(_ item: Any?) -> Node {
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

	// MARK: - Drag and Drop

	enum DraggedFeedsContentsType {
		case empty, singleLocal, singleNonLocal, multipleLocal, multipleNonLocal, mixed
	}

	func draggedFeedContentsType(_ draggedFeeds: Set<PasteboardFeed>) -> DraggedFeedsContentsType {
		if draggedFeeds.isEmpty {
			return .empty
		}
		if draggedFeeds.count == 1 {
			let feed = draggedFeeds.first!
			return feed.isLocalFeed ? .singleLocal : .singleNonLocal
		}

		var hasLocalFeed = false
		var hasNonLocalFeed = false
		for feed in draggedFeeds {
			if feed.isLocalFeed {
				hasLocalFeed = true
			}
			else {
				hasNonLocalFeed = true
			}
			if hasLocalFeed && hasNonLocalFeed {
				return .mixed
			}
		}
		if hasLocalFeed {
			return .multipleLocal
		}
		return .multipleNonLocal
	}

	func singleNonLocalFeed(from feeds: Set<PasteboardFeed>) -> PasteboardFeed? {
		guard feeds.count == 1, let feed = feeds.first else {
			return nil
		}
		return feed.isLocalFeed ? nil : feed
	}

	func validateLocalDrop(_ draggedFeeds: Set<PasteboardFeed>, parentNode: Node, proposedChildIndex index: Int) -> NSDragOperation {

//		let parentNode = nodeForItem(item)

		return SidebarOutlineDataSource.dragOperationNone
	}

	func validateSingleNonLocalFeedDrop(_ outlineView: NSOutlineView, _ draggedFeed: PasteboardFeed, _ parentNode: Node, _ index: Int) -> NSDragOperation {
		// A non-local feed should always drag on to an Account or Folder node, with NSOutlineViewDropOnItemIndex — since we don’t know where it would sort till we read the feed.
		guard let dropTargetNode = ancestorThatCanAcceptNonLocalFeed(parentNode) else {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if parentNode !== dropTargetNode || index != NSOutlineViewDropOnItemIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: NSOutlineViewDropOnItemIndex)
		}
		return .copy
	}

	func nodeIsAccountOrFolder(_ node: Node) -> Bool {
		return node.representedObject is Account || node.representedObject is Folder
	}

	func ancestorThatCanAcceptNonLocalFeed(_ node: Node) -> Node? {
		if node.canHaveChildNodes && nodeIsAccountOrFolder(node) {
			return node
		}
		guard let parentNode = node.parent else {
			return nil
		}
		return ancestorThatCanAcceptNonLocalFeed(parentNode)
	}
}
