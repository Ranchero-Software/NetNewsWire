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
		let draggedFolders = PasteboardFolder.pasteboardFolders(with: info.draggingPasteboard)
		let draggedFeeds = PasteboardFeed.pasteboardFeeds(with: info.draggingPasteboard)
		if (draggedFolders == nil && draggedFeeds == nil) || (draggedFolders != nil && draggedFeeds != nil)  {
			return SidebarOutlineDataSource.dragOperationNone
		}
		let parentNode = nodeForItem(item)

		if let draggedFolders = draggedFolders {
			if draggedFolders.count == 1 {
				return validateLocalFolderDrop(outlineView, draggedFolders.first!, parentNode, index)
			} else {
				return validateLocalFoldersDrop(outlineView, draggedFolders, parentNode, index)
			}
		}
		
		if let draggedFeeds = draggedFeeds {
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

		return SidebarOutlineDataSource.dragOperationNone
	}
	
	func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
		let draggedFolders = PasteboardFolder.pasteboardFolders(with: info.draggingPasteboard)
		let draggedFeeds = PasteboardFeed.pasteboardFeeds(with: info.draggingPasteboard)
		if (draggedFolders == nil && draggedFeeds == nil) || (draggedFolders != nil && draggedFeeds != nil)  {
			return false
		}
		let parentNode = nodeForItem(item)

		if let draggedFolders = draggedFolders {
			return acceptLocalFoldersDrop(outlineView, draggedFolders, parentNode, index)
		}
		
		if let draggedFeeds = draggedFeeds {
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
		// Don’t allow PseudoFeed to be dragged.
		// This will have to be revisited later. For instance,
		// user-created smart feeds should be draggable, maybe.
		return node.representedObject is Folder || node.representedObject is Feed
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
		if violatesTagSpecificBehavior(dropTargetNode, draggedFeed) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if parentNode == dropTargetNode && index == NSOutlineViewDropOnItemIndex {
			return localDragOperation()
		}
		let updatedIndex = indexWhereDraggedFeedWouldAppear(dropTargetNode, draggedFeed)
		if parentNode !== dropTargetNode || index != updatedIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: updatedIndex)
		}
		return localDragOperation()
	}

	func validateLocalFeedsDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardFeed>, _ parentNode: Node, _ index: Int) -> NSDragOperation {
		// Local feeds should always drag on to an Account or Folder node, and index should be NSOutlineViewDropOnItemIndex since we can’t provide multiple indexes.
		guard let dropTargetNode = ancestorThatCanAcceptLocalFeed(parentNode) else {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if nodeHasChildRepresentingAnyDraggedFeed(dropTargetNode, draggedFeeds) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if violatesTagSpecificBehavior(dropTargetNode, draggedFeeds) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if parentNode !== dropTargetNode || index != NSOutlineViewDropOnItemIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: NSOutlineViewDropOnItemIndex)
		}
		return localDragOperation()
	}
	
	func localDragOperation() -> NSDragOperation {
		if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
			return .copy
		} else {
			return .move
		}
	}

	func accountForNode(_ node: Node) -> Account? {
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

	func commonAccountsFor(_ nodes: Set<Node>) -> Set<Account> {

		var accounts = Set<Account>()
		for node in nodes {
			guard let oneAccount = accountForNode(node) else {
				continue
			}
			accounts.insert(oneAccount)
		}
		return accounts
	}

	func accountHasFolderRepresentingAnyDraggedFolders(_ account: Account, _ draggedFolders: Set<PasteboardFolder>) -> Bool {
		for draggedFolder in draggedFolders {
			if account.existingFolder(with: draggedFolder.name) != nil {
				return true
			}
		}
		return false
	}
	
	func validateLocalFolderDrop(_ outlineView: NSOutlineView, _ draggedFolder: PasteboardFolder, _ parentNode: Node, _ index: Int) -> NSDragOperation {
		guard let dropAccount = parentNode.representedObject as? Account, dropAccount.accountID != draggedFolder.accountID else {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if accountHasFolderRepresentingAnyDraggedFolders(dropAccount, Set([draggedFolder])) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		let updatedIndex = indexWhereDraggedFolderWouldAppear(parentNode, draggedFolder)
		if index != updatedIndex {
			outlineView.setDropItem(parentNode, dropChildIndex: updatedIndex)
		}
		return localDragOperation()
	}
	
	func validateLocalFoldersDrop(_ outlineView: NSOutlineView, _ draggedFolders: Set<PasteboardFolder>, _ parentNode: Node, _ index: Int) -> NSDragOperation {
		guard let dropAccount = parentNode.representedObject as? Account else {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if accountHasFolderRepresentingAnyDraggedFolders(dropAccount, draggedFolders) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		for draggedFolder in draggedFolders {
			if dropAccount.accountID == draggedFolder.accountID {
				return SidebarOutlineDataSource.dragOperationNone
			}
		}
		if index != NSOutlineViewDropOnItemIndex {
			outlineView.setDropItem(parentNode, dropChildIndex: NSOutlineViewDropOnItemIndex)
		}
		return localDragOperation()
	}
	
	func copyFeedInAccount(node: Node, to parentNode: Node) {
		guard let feed = node.representedObject as? Feed, let destination = parentNode.representedObject as? Container else {
			return
		}
		
		destination.account?.addFeed(feed, to: destination) { result in
			switch result {
			case .success:
				break
			case .failure(let error):
				NSApplication.shared.presentError(error)
			}
		}
	}

	func moveFeedInAccount(node: Node, to parentNode: Node) {
		guard let feed = node.representedObject as? Feed,
			let source = node.parent?.representedObject as? Container,
			let destination = parentNode.representedObject as? Container else {
			return
		}

		BatchUpdate.shared.start()
		source.account?.moveFeed(feed, from: source, to: destination) { result in
			BatchUpdate.shared.end()
			switch result {
			case .success:
				break
			case .failure(let error):
				NSApplication.shared.presentError(error)
			}
		}
	}

	func copyFeedBetweenAccounts(node: Node, to parentNode: Node) {
		guard let feed = node.representedObject as? Feed,
			let destinationAccount = nodeAccount(parentNode),
			let destinationContainer = parentNode.representedObject as? Container else {
			return
		}
		
		if let existingFeed = destinationAccount.existingFeed(withURL: feed.url) {
			destinationAccount.addFeed(existingFeed, to: destinationContainer) { result in
				switch result {
				case .success:
					break
				case .failure(let error):
					NSApplication.shared.presentError(error)
				}
			}
		} else {
			destinationAccount.createFeed(url: feed.url, name: feed.editedName, container: destinationContainer) { result in
				switch result {
				case .success:
					break
				case .failure(let error):
					NSApplication.shared.presentError(error)
				}
			}
		}
	}

	func moveFeedBetweenAccounts(node: Node, to parentNode: Node) {
		guard let feed = node.representedObject as? Feed,
			let sourceAccount = nodeAccount(node),
			let sourceContainer = node.parent?.representedObject as? Container,
			let destinationAccount = nodeAccount(parentNode),
			let destinationContainer = parentNode.representedObject as? Container else {
				return
		}
		
		if let existingFeed = destinationAccount.existingFeed(withURL: feed.url) {
			
			BatchUpdate.shared.start()
			destinationAccount.addFeed(existingFeed, to: destinationContainer) { result in
				switch result {
				case .success:
					sourceAccount.removeFeed(feed, from: sourceContainer) { result in
						BatchUpdate.shared.end()
						switch result {
						case .success:
							break
						case .failure(let error):
							NSApplication.shared.presentError(error)
						}
					}
				case .failure(let error):
					BatchUpdate.shared.end()
					NSApplication.shared.presentError(error)
				}
			}
			
		} else {
			
			BatchUpdate.shared.start()
			destinationAccount.createFeed(url: feed.url, name: feed.editedName, container: destinationContainer) { result in
				switch result {
				case .success:
					sourceAccount.removeFeed(feed, from: sourceContainer) { result in
						BatchUpdate.shared.end()
						switch result {
						case .success:
							break
						case .failure(let error):
							NSApplication.shared.presentError(error)
						}
					}
				case .failure(let error):
					BatchUpdate.shared.end()
					NSApplication.shared.presentError(error)
				}
			}
			
		}
	}

	func acceptLocalFeedsDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardFeed>, _ parentNode: Node, _ index: Int) -> Bool {
		guard let draggedNodes = draggedNodes else {
			return false
		}

		draggedNodes.forEach { node in
			if sameAccount(node, parentNode) {
				if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
					copyFeedInAccount(node: node, to: parentNode)
				} else {
					moveFeedInAccount(node: node, to: parentNode)
				}
			} else {
				if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
					copyFeedBetweenAccounts(node: node, to: parentNode)
				} else {
					moveFeedBetweenAccounts(node: node, to: parentNode)
				}
			}
		}
		
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

	func copyFolderBetweenAccounts(node: Node, to parentNode: Node) {
		guard let sourceFolder = node.representedObject as? Folder,
			let destinationAccount = nodeAccount(parentNode) else {
				return
		}
		replicateFolder(sourceFolder, destinationAccount: destinationAccount, completion: {})
	}
	
	func moveFolderBetweenAccounts(node: Node, to parentNode: Node) {
		guard let sourceFolder = node.representedObject as? Folder,
			let sourceAccount = nodeAccount(node),
			let destinationAccount = nodeAccount(parentNode) else {
				return
		}
		
		BatchUpdate.shared.start()
		replicateFolder(sourceFolder, destinationAccount: destinationAccount) {
			sourceAccount.removeFolder(sourceFolder) { result in
				BatchUpdate.shared.end()
				switch result {
				case .success:
					break
				case .failure(let error):
					NSApplication.shared.presentError(error)
				}
			}
		}
	}
	
	func replicateFolder(_ folder: Folder, destinationAccount: Account, completion: @escaping () -> Void) {
		destinationAccount.addFolder(folder.name ?? "") { result in
			switch result {
			case .success(let destinationFolder):
				let group = DispatchGroup()
				for feed in folder.topLevelFeeds {
					if let existingFeed = destinationAccount.existingFeed(withURL: feed.url) {
						group.enter()
						destinationAccount.addFeed(existingFeed, to: destinationFolder) { result in
							group.leave()
							switch result {
							case .success:
								break
							case .failure(let error):
								NSApplication.shared.presentError(error)
							}
						}
					} else {
						group.enter()
						destinationAccount.createFeed(url: feed.url, name: feed.editedName, container: destinationFolder) { result in
							group.leave()
							switch result {
							case .success:
								break
							case .failure(let error):
								NSApplication.shared.presentError(error)
							}
						}
					}
				}
				group.notify(queue: DispatchQueue.main) {
					completion()
				}
			case .failure(let error):
				NSApplication.shared.presentError(error)
				completion()
			}
		}

	}

	func acceptLocalFoldersDrop(_ outlineView: NSOutlineView, _ draggedFolders: Set<PasteboardFolder>, _ parentNode: Node, _ index: Int) -> Bool {
		guard let draggedNodes = draggedNodes else {
			return false
		}
		
		draggedNodes.forEach { node in
			if !sameAccount(node, parentNode) {
				if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
					copyFolderBetweenAccounts(node: node, to: parentNode)
				} else {
					moveFolderBetweenAccounts(node: node, to: parentNode)
				}
			}
		}
		
		return true
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
	
	func sameAccount(_ node: Node, _ parentNode: Node) -> Bool {
		if let accountID = nodeAccountID(node), let parentAccountID = nodeAccountID(parentNode) {
			if accountID == parentAccountID {
				return true
			}
		}
		return false
	}
	
	func nodeAccount(_ node: Node) -> Account? {
		if let account = node.representedObject as? Account {
			return account
		} else if let folder = node.representedObject as? Folder {
			return folder.account
		} else if let feed = node.representedObject as? Feed {
			return feed.account
		} else {
			return nil
		}

	}
	
	func nodeAccountID(_ node: Node) -> String? {
		return nodeAccount(node)?.accountID
	}
	
	func nodeHasChildRepresentingAnyDraggedFeed(_ parentNode: Node, _ draggedFeeds: Set<PasteboardFeed>) -> Bool {
		for node in parentNode.childNodes {
			if nodeRepresentsAnyDraggedFeed(node, draggedFeeds) {
				return true
			}
		}
		return false
	}

	func violatesTagSpecificBehavior(_ parentNode: Node, _ draggedFeed: PasteboardFeed) -> Bool {
		return violatesTagSpecificBehavior(parentNode, Set([draggedFeed]))
	}
	
	func violatesTagSpecificBehavior(_ parentNode: Node, _ draggedFeeds: Set<PasteboardFeed>) -> Bool {
		guard let parentAccount = nodeAccount(parentNode), parentAccount.isTagBasedSystem else {
			return false
		}
		
		for draggedFeed in draggedFeeds {
			if parentAccount.accountID != draggedFeed.accountID {
				return false
			}
		}
		
		// Can't copy to the account when using tags
		if parentNode.representedObject is Account && (NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false) {
			return true
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

	func indexWhereDraggedFolderWouldAppear(_ parentNode: Node, _ draggedFolder: PasteboardFolder) -> Int {
		let draggedFolderWrapper = PasteboardFolderObjectWrapper(pasteboardFolder: draggedFolder)
		let draggedFolderNode = Node(representedObject: draggedFolderWrapper, parent: nil)
		draggedFolderNode.canHaveChildNodes = true
		let nodes = parentNode.childNodes + [draggedFolderNode]
		
		// Revisit if the tree controller can ever be sorted in some other way.
		let sortedNodes = nodes.sortedAlphabeticallyWithFoldersAtEnd()
		let index = sortedNodes.firstIndex(of: draggedFolderNode)!
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

final class PasteboardFolderObjectWrapper: DisplayNameProvider {
	
	var nameForDisplay: String {
		return pasteboardFolder.name
	}
	let pasteboardFolder: PasteboardFolder
	
	init(pasteboardFolder: PasteboardFolder) {
		self.pasteboardFolder = pasteboardFolder
	}
}
