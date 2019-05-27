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
		if !allParticipantsAreLocalAccounts(dropTargetNode, Set([draggedFeed])) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if nodeHasChildRepresentingDraggedFeed(dropTargetNode, draggedFeed) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		let dragOperation: NSDragOperation = localFeedsDropOperation(dropTargetNode, Set([draggedFeed]))
		if parentNode == dropTargetNode && index == NSOutlineViewDropOnItemIndex {
			return dragOperation
		}
		let updatedIndex = indexWhereDraggedFeedWouldAppear(dropTargetNode, draggedFeed)
		if parentNode !== dropTargetNode || index != updatedIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: updatedIndex)
		}
		return dragOperation
	}

	func validateLocalFeedsDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardFeed>, _ parentNode: Node, _ index: Int) -> NSDragOperation {
		// Local feeds should always drag on to an Account or Folder node, and index should be NSOutlineViewDropOnItemIndex since we can’t provide multiple indexes.
		guard let dropTargetNode = ancestorThatCanAcceptLocalFeed(parentNode) else {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if !allParticipantsAreLocalAccounts(dropTargetNode, draggedFeeds) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if nodeHasChildRepresentingAnyDraggedFeed(dropTargetNode, draggedFeeds) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if parentNode !== dropTargetNode || index != NSOutlineViewDropOnItemIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: NSOutlineViewDropOnItemIndex)
		}
		return localFeedsDropOperation(dropTargetNode, draggedFeeds)
	}
	
	func localFeedsDropOperation(_ dropTargetNode: Node, _ draggedFeeds: Set<PasteboardFeed>) -> NSDragOperation {
		if allParticipantsAreSameAccount(dropTargetNode, draggedFeeds) {
			return .move
		}
		if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
			return .copy
		} else {
			return .move
		}
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

	private func commonAccountsFor(_ nodes: Set<Node>) -> Set<Account> {

		var accounts = Set<Account>()
		for node in nodes {
			guard let oneAccount = accountForNode(node) else {
				continue
			}
			accounts.insert(oneAccount)
		}
		return accounts
	}

	private func copy(node: Node, to parentNode: Node) {
		guard let feed = node.representedObject as? Feed else {
			return
		}

		let destination = parentNode.representedObject as? Container

		BatchUpdate.shared.start()
		destination?.addFeed(feed) { result in
			switch result {
			case .success:
				BatchUpdate.shared.end()
				break
			case .failure(let error):
				BatchUpdate.shared.end()
				NSApplication.shared.presentError(error)
			}
		}
	}

	private func move(node: Node, to parentNode: Node) {
		guard let feed = node.representedObject as? Feed else {
			return
		}

		let source = node.parent?.representedObject as? Container
		let destination = parentNode.representedObject as? Container

		BatchUpdate.shared.start()
		source?.removeFeed(feed) { result in
			switch result {
			case .success:
				destination?.addFeed(feed) { result in
					switch result {
					case .success:
						BatchUpdate.shared.end()
						break
					case .failure(let error):
						// If the second part of the move failed, try to put the feed back
						source?.addFeed(feed) { result in}
						BatchUpdate.shared.end()
						NSApplication.shared.presentError(error)
					}
				}
			case .failure(let error):
				NSApplication.shared.presentError(error)
			}
			
		}
	}

	func acceptLocalFeedsDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardFeed>, _ parentNode: Node, _ index: Int) -> Bool {
		guard let draggedNodes = draggedNodes else {
			return false
		}

		BatchUpdate.shared.perform {
			
			draggedNodes.forEach { node in
				if sameAccount(node, parentNode) {
					move(node: node, to: parentNode)
				} else if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
					copy(node: node, to: parentNode)
				} else {
					move(node: node, to: parentNode)
				}
			}
			
		}
		
		let allReferencedNodes = draggedNodes.union(Set([parentNode]))
		let accounts = commonAccountsFor(allReferencedNodes)
		accounts.forEach { $0.structureDidChange() }

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
			if let onMyMacAccountNode = treeController.nodeInTreeRepresentingObject(AccountManager.shared.defaultAccount) {
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
		if let account = parentNode.representedObject as? Account {
			appDelegate.addFeed(draggedFeed.url, name: draggedFeed.editedName ?? draggedFeed.name, account: account, folder: nil)
		} else {
			let account = parentNode.parent?.representedObject as? Account
			let folder = parentNode.representedObject as? Folder
			appDelegate.addFeed(draggedFeed.url, name: draggedFeed.editedName ?? draggedFeed.name, account: account, folder: folder)
		}
		
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
	
	func allParticipantsAreLocalAccounts(_ parentNode: Node, _ draggedFeeds: Set<PasteboardFeed>) -> Bool {
		
		if let account = parentNode.representedObject as? Account {
			if account.type != .onMyMac {
				return false
			}
		} else if let folder = parentNode.representedObject as? Folder {
			if folder.account?.type != .onMyMac {
				return false
			}
		} else {
			return false
		}
		
		for draggedFeed in draggedFeeds {
			if draggedFeed.accountType != .onMyMac {
				return false
			}
		}
		
		return true
		
	}

	func allParticipantsAreSameAccount(_ parentNode: Node, _ draggedFeeds: Set<PasteboardFeed>) -> Bool {
		guard let parentAccountID = nodeAccountID(parentNode) else {
			return false
		}
		
		for draggedFeed in draggedFeeds {
			if draggedFeed.accountID != parentAccountID {
				return false
			}
		}
		
		return true
	}
	
	func sameAccount(_ node: Node, _ parentNode: Node) -> Bool {
		if let accountID = nodeAccountID(node), let parentAccountID = nodeAccountID(parentNode) {
			if accountID == parentAccountID {
				return true
			}
		}
		return false
	}
	
	func nodeAccountID(_ node: Node) -> String? {
		if let account = node.representedObject as? Account {
			return account.accountID
		} else if let folder = node.representedObject as? Folder {
			return folder.account?.accountID
		} else if let feed = node.representedObject as? Feed {
			return feed.account?.accountID
		} else {
			return nil
		}
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
