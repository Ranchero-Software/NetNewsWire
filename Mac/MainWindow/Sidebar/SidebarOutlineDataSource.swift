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
	private var draggedNodes: Set<Node>? = nil

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

	func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItems draggedItems: [Any]) {
		draggedNodes = Set(draggedItems.map { nodeForItem($0) })
	}

	func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
		guard let draggedFeeds = PasteboardFeed.pasteboardFeeds(with: info.draggingPasteboard), !draggedFeeds.isEmpty else {
			return SidebarOutlineDataSource.dragOperationNone
		}

		let parentNode = nodeForItem(item)
		let contentsType = draggedFeedContentsType(draggedFeeds)

		switch contentsType {
		case .singleNonLocal:
			let draggedNonLocalFeed = singleNonLocalFeed(from: draggedFeeds)!
			return validateSingleNonLocalFeedDrop(outlineView, draggedNonLocalFeed, parentNode, index)
		case .singleLocal:
			let draggedFeed = draggedFeeds.first!
			return validateSingleLocalFeedDrop(outlineView, draggedFeed, parentNode, index)
		case .multipleLocal:
			return validateLocalFeedsDrop(outlineView, draggedFeeds, parentNode, index)
		case .multipleNonLocal, .mixed, .empty:
			return SidebarOutlineDataSource.dragOperationNone
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
		guard let draggedFeeds = PasteboardFeed.pasteboardFeeds(with: info.draggingPasteboard), !draggedFeeds.isEmpty else {
			return false
		}

		let parentNode = nodeForItem(item)
		let contentsType = draggedFeedContentsType(draggedFeeds)

		switch contentsType {
		case .singleNonLocal:
			let draggedNonLocalFeed = singleNonLocalFeed(from: draggedFeeds)!
			return acceptSingleNonLocalFeedDrop(outlineView, draggedNonLocalFeed, parentNode, index)
		case .singleLocal:
			return acceptLocalFeedsDrop(outlineView, draggedFeeds, parentNode, index)
		case .multipleLocal:
			return acceptLocalFeedsDrop(outlineView, draggedFeeds, parentNode, index)
		case .multipleNonLocal, .mixed, .empty:
			return false
		}
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

	func validateSingleLocalFeedDrop(_ outlineView: NSOutlineView, _ draggedFeed: PasteboardFeed, _ parentNode: Node, _ index: Int) -> NSDragOperation {
		// A local feed should always drag on to an Account or Folder node, and we can provide an index.
		guard let dropTargetNode = ancestorThatCanAcceptLocalFeed(parentNode) else {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if nodeHasChildRepresentingDraggedFeed(dropTargetNode, draggedFeed) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if parentNode == dropTargetNode && index == NSOutlineViewDropOnItemIndex {
			return .move
		}
		let updatedIndex = indexWhereDraggedFeedWouldAppear(dropTargetNode, draggedFeed)
		if parentNode !== dropTargetNode || index != updatedIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: updatedIndex)
		}
		return .move
	}

	func validateLocalFeedsDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardFeed>, _ parentNode: Node, _ index: Int) -> NSDragOperation {
		// Local feeds should always drag on to an Account or Folder node, and index should be NSOutlineViewDropOnItemIndex since we can’t provide multiple indexes.
		guard let dropTargetNode = ancestorThatCanAcceptLocalFeed(parentNode) else {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if nodeHasChildRepresentingAnyDraggedFeed(dropTargetNode, draggedFeeds) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if parentNode !== dropTargetNode || index != NSOutlineViewDropOnItemIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: NSOutlineViewDropOnItemIndex)
		}
		return .move
	}

	private func accountForNode(_ node: Node) -> Account? {
		if let account = node.representedObject as? Account {
			return account
		}
		if let folder = node.representedObject as? Folder {
			return folder.account
		}
		if let feed = node.representedObject as? Feed {
			return feed.account
		}
		return nil
	}

	private func commonAccountFor(_ nodes: Set<Node>) -> Account? {
		// Return the Account if every node has an Account and they’re all the same.
		var account: Account? = nil
		for node in nodes {
			guard let oneAccount = accountForNode(node) else {
				return nil
			}
			if account == nil {
				account = oneAccount
			}
			else {
				if account != oneAccount {
					return nil
				}
			}
		}
		return account
	}

	private func move(node: Node, to parentNode: Node, account: Account) {
		guard let feed = node.representedObject as? Feed else {
			return
		}
		let sourceContainer = node.parent?.representedObject as? Container
		let destinationFolder = parentNode.representedObject as? Folder
		sourceContainer?.deleteFeed(feed)
		account.addFeed(feed, to: destinationFolder)
	}

	func acceptLocalFeedsDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardFeed>, _ parentNode: Node, _ index: Int) -> Bool {
		guard let draggedNodes = draggedNodes else {
			return false
		}
		let allReferencedNodes = draggedNodes.union(Set([parentNode]))
		guard let account = commonAccountFor(allReferencedNodes) else {
			return false
		}
		BatchUpdate.shared.perform {
			draggedNodes.forEach { move(node: $0, to: parentNode, account: account) }
		}
		account.structureDidChange()
		return true
	}

	func nodeIsAccountOrFolder(_ node: Node) -> Bool {
		return node.representedObject is Account || node.representedObject is Folder
	}

	func nodeIsDropTarget(_ node: Node) -> Bool {
		return node.canHaveChildNodes && nodeIsAccountOrFolder(node)
	}

	func ancestorThatCanAcceptLocalFeed(_ node: Node) -> Node? {
		if nodeIsDropTarget(node) {
			return node
		}
		guard let parentNode = node.parent else {
			return nil
		}
		return ancestorThatCanAcceptLocalFeed(parentNode)
	}

	func ancestorThatCanAcceptNonLocalFeed(_ node: Node) -> Node? {
		// Default to the On My Mac account, if needed, so we can always accept a nonlocal feed drop.
		if nodeIsDropTarget(node) {
			return node
		}
		guard let parentNode = node.parent else {
			if let onMyMacAccountNode = treeController.nodeInTreeRepresentingObject(AccountManager.shared.localAccount) {
				return onMyMacAccountNode
			}
			return nil
		}
		return ancestorThatCanAcceptNonLocalFeed(parentNode)
	}

	func acceptSingleNonLocalFeedDrop(_ outlineView: NSOutlineView, _ draggedFeed: PasteboardFeed, _ parentNode: Node, _ index: Int) -> Bool {
		guard nodeIsDropTarget(parentNode), index == NSOutlineViewDropOnItemIndex else {
			return false
		}

		// Show the add-feed sheet.
		let folder = parentNode.representedObject as? Folder
		appDelegate.addFeed(draggedFeed.url, name: draggedFeed.editedName ?? draggedFeed.name, folder: folder)
		return true
	}

	func nodeHasChildRepresentingDraggedFeed(_ parentNode: Node, _ draggedFeed: PasteboardFeed) -> Bool {
		return nodeHasChildRepresentingAnyDraggedFeed(parentNode, Set([draggedFeed]))
	}

	func nodeRepresentsAnyDraggedFeed(_ node: Node, _ draggedFeeds: Set<PasteboardFeed>) -> Bool {
		guard let feed = node.representedObject as? Feed else {
			return false
		}
		for draggedFeed in draggedFeeds {
			if feed.url == draggedFeed.url {
				return true
			}
		}
		return false
	}

	func nodeHasChildRepresentingAnyDraggedFeed(_ parentNode: Node, _ draggedFeeds: Set<PasteboardFeed>) -> Bool {
		for node in parentNode.childNodes {
			if nodeRepresentsAnyDraggedFeed(node, draggedFeeds) {
				return true
			}
		}
		return false
	}

	func indexWhereDraggedFeedWouldAppear(_ parentNode: Node, _ draggedFeed: PasteboardFeed) -> Int {
		let draggedFeedWrapper = PasteboardFeedObjectWrapper(pasteboardFeed: draggedFeed)
		let draggedFeedNode = Node(representedObject: draggedFeedWrapper, parent: nil)
		let nodes = parentNode.childNodes + [draggedFeedNode]

		// Revisit if the tree controller can ever be sorted in some other way.
		let sortedNodes = nodes.sortedAlphabeticallyWithFoldersAtEnd()
		let index = sortedNodes.firstIndex(of: draggedFeedNode)!
		return index
	}
}

final class PasteboardFeedObjectWrapper: DisplayNameProvider {

	var nameForDisplay: String {
		return pasteboardFeed.editedName ?? pasteboardFeed.name ?? ""
	}
	let pasteboardFeed: PasteboardFeed

	init(pasteboardFeed: PasteboardFeed) {
		self.pasteboardFeed = pasteboardFeed
	}
}
