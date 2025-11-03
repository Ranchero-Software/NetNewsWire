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
		guard var pasteboardWriter = (node.representedObject as? PasteboardWriterOwner)?.pasteboardWriter else {
			return nil
		}
		
		// Feed objects don't have knowledge of their parent so we inject parent container information
		// into FeedPasteboardWriter instance and it adds this field to the PasteboardFeed objects it writes.
		// Add similar to FolderPasteboardWriter if/when we allow sub-folders
		if let feedWriter = pasteboardWriter as? FeedPasteboardWriter {
			if let parentContainerID = (node.parent?.representedObject as? Folder)?.containerID {
				feedWriter.containerID = parentContainerID
				pasteboardWriter = feedWriter
			}
		}
		return pasteboardWriter
	}

	// MARK: - Drag and Drop

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
		if violatesAccountSpecificBehavior(dropTargetNode, draggedFeed) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if parentNode == dropTargetNode && index == NSOutlineViewDropOnItemIndex {
			return localDragOperation(parentNode: parentNode, Set([draggedFeed]))
		}
		let updatedIndex = indexWhereDraggedFeedWouldAppear(dropTargetNode, draggedFeed)
		if parentNode !== dropTargetNode || index != updatedIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: updatedIndex)
		}
		return localDragOperation(parentNode: parentNode, Set([draggedFeed]))
	}

	func validateLocalFeedsDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardFeed>, _ parentNode: Node, _ index: Int) -> NSDragOperation {
		// Local feeds should always drag on to an Account or Folder node, and index should be NSOutlineViewDropOnItemIndex since we can’t provide multiple indexes.
		guard let dropTargetNode = ancestorThatCanAcceptLocalFeed(parentNode) else {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if nodeHasChildRepresentingAnyDraggedFeed(dropTargetNode, draggedFeeds) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if violatesAccountSpecificBehavior(dropTargetNode, draggedFeeds) {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if parentNode !== dropTargetNode || index != NSOutlineViewDropOnItemIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: NSOutlineViewDropOnItemIndex)
		}
		return localDragOperation(parentNode: parentNode, draggedFeeds)
	}
	
	func localDragOperation(parentNode: Node, _ draggedFeeds: Set<PasteboardFeed>)-> NSDragOperation {
		guard let firstDraggedFeed = draggedFeeds.first else { return .move }
		if sameAccount(firstDraggedFeed, parentNode) {
			if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
				return .copy
			} else {
				return .move
			}
		} else {
			return .copy
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
		return .copy	// different AccountIDs means can only copy 
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
		return .copy	// different AccountIDs means can only copy
	}
	
	func copyFeedInAccount(_ feed: Feed, _ destination: Container ) {
		destination.account?.addFeed(feed, to: destination) { result in
			switch result {
			case .success:
				break
			case .failure(let error):
				NSApplication.shared.presentError(error)
			}
		}
	}
	
	func moveFeedInAccount(_ feed: Feed, _ source: Container, _ destination: Container) {
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
	
	func copyFeedBetweenAccounts(_ feed: Feed, _ destinationContainer: Container) {
		guard let destinationAccount = destinationContainer.account  else {
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
			destinationAccount.createFeed(url: feed.url, name: feed.nameForDisplay, container: destinationContainer, validateFeed: false) { result in
				switch result {
				case .success:
					break
				case .failure(let error):
					NSApplication.shared.presentError(error)
				}
			}
		}
	}

	func acceptLocalFeedsDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardFeed>, _ parentNode: Node, _ index: Int) -> Bool {
		guard draggedFeeds.isEmpty == false else {
			return false
		}
		
		draggedFeeds.forEach { pasteboardFeed in
			guard let sourceAccountID = pasteboardFeed.accountID,
				  let sourceAccount = AccountManager.shared.existingAccount(with: sourceAccountID),
				  let feedID = pasteboardFeed.feedID,
				  let feed = sourceAccount.existingFeed(withFeedID:  feedID),
				  let destinationContainer = parentNode.representedObject as? Container
			else {
				return
			}
			
			var sourceContainer: Container = sourceAccount				// default to top level,
			if let containerName = pasteboardFeed.containerName {		// then check if have folder info to use instead.
				if let folderContainer = sourceAccount.existingFolder(with: containerName ) {
					sourceContainer = folderContainer
				} else if let folderContainer = sourceAccount.existingFolder(withDisplayName: containerName) {
					sourceContainer = folderContainer
				}
			}
			
			if sameAccount(pasteboardFeed, parentNode) {
				if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
					copyFeedInAccount(feed, destinationContainer)
				} else {
					moveFeedInAccount(feed, sourceContainer, destinationContainer)
				}
			} else {
				copyFeedBetweenAccounts(feed, destinationContainer)
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
	
	func copyFolderBetweenAccounts(folder: Folder, to parentNode: Node) {
		guard let destinationAccount = nodeAccount(parentNode) else {
			return
		}
		
		destinationAccount.addFolder(folder.name ?? "") { result in
			switch result {
			case .success(let destinationFolder):
				for feed in folder.topLevelFeeds {
					if let existingFeed = destinationAccount.existingFeed(withURL: feed.url) {
						destinationAccount.addFeed(existingFeed, to: destinationFolder) { result in
							switch result {
							case .success:
								break
							case .failure(let error):
								NSApplication.shared.presentError(error)
							}
						}
					} else {
						destinationAccount.createFeed(url: feed.url, name: feed.nameForDisplay, container: destinationFolder, validateFeed: false) { result in
							switch result {
							case .success:
								break
							case .failure(let error):
								NSApplication.shared.presentError(error)
							}
						}
					}
				}
			case .failure(let error):
				NSApplication.shared.presentError(error)
			}
		}
	}

	func acceptLocalFoldersDrop(_ outlineView: NSOutlineView, _ draggedFolders: Set<PasteboardFolder>, _ parentNode: Node, _ index: Int) -> Bool {
		guard draggedFolders.isEmpty == false else {
			return false
		}

		draggedFolders.forEach { pasteboardFolder in
			guard let sourceAccountID = pasteboardFolder.accountID,
				  let sourceAccount = AccountManager.shared.existingAccount(with: sourceAccountID),
				  let folderStringID = pasteboardFolder.folderID,
				  let folderID = Int(folderStringID),
				  let folder = sourceAccount.existingFolder(withID: folderID)
			else {
				return
			}
			if !sameAccount(pasteboardFolder, parentNode) {
				copyFolderBetweenAccounts(folder: folder, to: parentNode)
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
	
	func sameAccount(_ pasteboardFeed: PasteboardFeed, _ parentNode: Node) -> Bool {
		if let accountID = pasteboardFeed.accountID {
			return sameAccount(accountID, parentNode)
		}
		return false
	}
	
	func sameAccount(_ pasteboardFolder: PasteboardFolder, _ parentNode: Node) -> Bool {
		if let accountID = pasteboardFolder.accountID {
			return sameAccount(accountID, parentNode)
		}
		return false
	}

	func sameAccount(_ accountID: String, _ parentNode: Node) -> Bool {
		if let parentAccountID = nodeAccountID(parentNode) {
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

	func violatesAccountSpecificBehavior(_ dropTargetNode: Node, _ draggedFeed: PasteboardFeed) -> Bool {
		return violatesAccountSpecificBehavior(dropTargetNode, Set([draggedFeed]))
	}
	
	func violatesAccountSpecificBehavior(_ dropTargetNode: Node, _ draggedFeeds: Set<PasteboardFeed>) -> Bool {
		if violatesDisallowFeedInRootFolder(dropTargetNode) {
			return true
		}

		if violatesDisallowFeedCopyInRootFolder(dropTargetNode, draggedFeeds) {
			return true
		}
		
		if violatesDisallowFeedInMultipleFolders(dropTargetNode, draggedFeeds) {
			return true
		}
		
		return false
	}
	
	func violatesDisallowFeedInRootFolder(_ dropTargetNode: Node) -> Bool {
		guard let parentAccount = nodeAccount(dropTargetNode), parentAccount.behaviors.contains(.disallowFeedInRootFolder) else {
			return false
		}
		
		if dropTargetNode.representedObject is Account {
			return true
		}
		
		return false
	}

	func violatesDisallowFeedCopyInRootFolder(_ dropTargetNode: Node, _ draggedFeeds: Set<PasteboardFeed>) -> Bool {
		guard let dropTargetAccount = nodeAccount(dropTargetNode), dropTargetAccount.behaviors.contains(.disallowFeedCopyInRootFolder) else {
			return false
		}
		
		for draggedFeed in draggedFeeds {
			if dropTargetAccount.accountID != draggedFeed.accountID {
				return false
			}
		}
		
		if dropTargetNode.representedObject is Account && (NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false) {
			return true
		}
		
		return false
	}

	func violatesDisallowFeedInMultipleFolders(_ dropTargetNode: Node, _ draggedFeeds: Set<PasteboardFeed>) -> Bool {
		guard let dropTargetAccount = nodeAccount(dropTargetNode), dropTargetAccount.behaviors.contains(.disallowFeedInMultipleFolders) else {
			return false
		}
		
		for draggedFeed in draggedFeeds {
			if dropTargetAccount.accountID == draggedFeed.accountID {
				if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
					return true
				}
			} else {
				if dropTargetAccount.hasFeed(withURL: draggedFeed.url) {
					return true
				}
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
