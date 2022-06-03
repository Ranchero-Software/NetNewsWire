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
		let draggedFeeds = PasteboardWebFeed.pasteboardFeeds(with: info.draggingPasteboard)
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
		let draggedFeeds = PasteboardWebFeed.pasteboardFeeds(with: info.draggingPasteboard)
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
		return node.representedObject is Folder || node.representedObject is WebFeed
	}

	// MARK: - Drag and Drop

	enum DraggedFeedsContentsType {
		case empty, singleLocal, singleNonLocal, multipleLocal, multipleNonLocal, mixed
	}

	func draggedFeedContentsType(_ draggedFeeds: Set<PasteboardWebFeed>) -> DraggedFeedsContentsType {
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

	func singleNonLocalFeed(from feeds: Set<PasteboardWebFeed>) -> PasteboardWebFeed? {
		guard feeds.count == 1, let feed = feeds.first else {
			return nil
		}
		return feed.isLocalFeed ? nil : feed
	}

	func validateSingleNonLocalFeedDrop(_ outlineView: NSOutlineView, _ draggedFeed: PasteboardWebFeed, _ parentNode: Node, _ index: Int) -> NSDragOperation {
		// A non-local feed should always drag on to an Account or Folder node, with NSOutlineViewDropOnItemIndex — since we don’t know where it would sort till we read the feed.
		guard let dropTargetNode = ancestorThatCanAcceptNonLocalFeed(parentNode) else {
			return SidebarOutlineDataSource.dragOperationNone
		}
		if parentNode !== dropTargetNode || index != NSOutlineViewDropOnItemIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: NSOutlineViewDropOnItemIndex)
		}
		return .copy
	}

	func validateSingleLocalFeedDrop(_ outlineView: NSOutlineView, _ draggedFeed: PasteboardWebFeed, _ parentNode: Node, _ index: Int) -> NSDragOperation {
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
			if draggedNodes?.isEmpty == false {
				return localDragOperation(parentNode: parentNode)
			}
			else {
				return localDragFeedPasteboardOperation(parentNode: parentNode, Set([draggedFeed]))
			}
		}
		let updatedIndex = indexWhereDraggedFeedWouldAppear(dropTargetNode, draggedFeed)
		if parentNode !== dropTargetNode || index != updatedIndex {
			outlineView.setDropItem(dropTargetNode, dropChildIndex: updatedIndex)
		}
		if draggedNodes?.isEmpty == false {
			return localDragOperation(parentNode: parentNode)
		}
		else {
			return localDragFeedPasteboardOperation(parentNode: parentNode, Set([draggedFeed]))
		}
	}

	func validateLocalFeedsDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardWebFeed>, _ parentNode: Node, _ index: Int) -> NSDragOperation {
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
		if draggedNodes?.isEmpty == false {
			return localDragOperation(parentNode: parentNode)
		}
		else {
			return localDragFeedPasteboardOperation(parentNode: parentNode, draggedFeeds)
		}
	}
	
	func localDragOperation(parentNode: Node) -> NSDragOperation {
		guard let firstDraggedNode = draggedNodes?.first else { return .move }
		if sameAccount(firstDraggedNode, parentNode) {
			return dragCopyOrMove()
		} else {
			return .copy
		}
	}
	
	func localDragFeedPasteboardOperation(parentNode: Node, _ draggedFeeds: Set<PasteboardWebFeed>)-> NSDragOperation {
		guard let firstDraggedFeed = draggedFeeds.first else { return .move }
		if sameAccount(firstDraggedFeed, parentNode) {
			return dragCopyOrMove()
		} else {
			return .copy
		}
	}
		
	func dragCopyOrMove() -> NSDragOperation {
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
		if let feed = node.representedObject as? WebFeed {
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
		// TODO: handle local folder drags between windows
		return localDragOperation(parentNode: parentNode)
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
		// TODO: handle local folder drags between windows
		return localDragOperation(parentNode: parentNode)
	}
	
	func copyWebFeedInAccount(node: Node, to parentNode: Node) {
		guard let feed = node.representedObject as? WebFeed,
			  let destination = parentNode.representedObject as? Container
		else {
			return
		}
		copyWebFeedInAccount(feed, destination)
	}
	
	func copyWebFeedInAccount(_ feed: WebFeed, _ destination: Container ) {
		destination.account?.addWebFeed(feed, to: destination) { result in
			switch result {
			case .success:
				break
			case .failure(let error):
				NSApplication.shared.presentError(error)
			}
		}
	}

	func moveWebFeedInAccount(node: Node, to parentNode: Node) {
		guard let feed = node.representedObject as? WebFeed,
			let source = node.parent?.representedObject as? Container,
			let destination = parentNode.representedObject as? Container else {
			return
		}
		moveWebFeedInAccount(feed, source, destination)
	}
	
	func moveWebFeedInAccount(_ feed: WebFeed, _ source: Container, _ destination: Container) {
		BatchUpdate.shared.start()
		source.account?.moveWebFeed(feed, from: source, to: destination) { result in
			BatchUpdate.shared.end()
			switch result {
			case .success:
				break
			case .failure(let error):
				NSApplication.shared.presentError(error)
			}
		}
	}

	func copyWebFeedBetweenAccounts(node: Node, to parentNode: Node) {
		guard let feed = node.representedObject as? WebFeed,
			let destinationAccount = nodeAccount(parentNode),
			let destinationContainer = parentNode.representedObject as? Container else {
			return
		}
		copyWebFeedBetweenAccounts(feed, destinationAccount, destinationContainer)
	}
	
	func copyWebFeedBetweenAccounts(_ feed: WebFeed, _ destinationAccount: Account, _ destinationContainer: Container) {
		if let existingFeed = destinationAccount.existingWebFeed(withURL: feed.url) {
			destinationAccount.addWebFeed(existingFeed, to: destinationContainer) { result in
				switch result {
				case .success:
					break
				case .failure(let error):
					NSApplication.shared.presentError(error)
				}
			}
		} else {
			destinationAccount.createWebFeed(url: feed.url, name: feed.nameForDisplay, container: destinationContainer, validateFeed: false) { result in
				switch result {
				case .success:
					break
				case .failure(let error):
					NSApplication.shared.presentError(error)
				}
			}
		}
	}

	func acceptLocalFeedsDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardWebFeed>, _ parentNode: Node, _ index: Int) -> Bool {
		if draggedNodes != nil {
			return acceptLocalFeedsNodeDrop(outlineView, parentNode: parentNode, index)
		} else {
			return acceptLocalFeedsPastboardDrop(outlineView, draggedFeeds, parentNode, index)
		}
	}
	
	func acceptLocalFeedsNodeDrop( _ outlineView: NSOutlineView, parentNode: Node, _ index: Int) -> Bool {
		guard let draggedNodes = draggedNodes else {
			return false
		}
		
		draggedNodes.forEach { node in
			if sameAccount(node, parentNode) {
				if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
					copyWebFeedInAccount(node: node, to: parentNode)
				} else {
					moveWebFeedInAccount(node: node, to: parentNode)
				}
			} else {
				copyWebFeedBetweenAccounts(node: node, to: parentNode)
			}
		}
		
		return true
	}
	
	func acceptLocalFeedsPastboardDrop(_ outlineView: NSOutlineView, _ draggedFeeds: Set<PasteboardWebFeed>, _ parentNode: Node, _ index: Int) -> Bool {
		guard draggedFeeds.isEmpty == false else {
			return false
		}
		
		draggedFeeds.forEach { pasteboardFeed in
			guard let accountID = pasteboardFeed.accountID,
				  let account = AccountManager.shared.existingAccount(with: accountID),
				  let webFeedID = pasteboardFeed.webFeedID,
				  let feed = account.existingWebFeed(withWebFeedID:  webFeedID),
				  let destination = parentNode.representedObject as? Container
			else {
				return
			}

			if sameAccount(pasteboardFeed, parentNode) {
				if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
					copyWebFeedInAccount(feed, destination)
				} else {
					moveWebFeedInAccount(feed, account, destination)
				}
			} else {
				copyWebFeedBetweenAccounts(feed, account, destination)
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
		guard let folder = node.representedObject as? Folder else {
			return
		}
		copyFolderBetweenAccounts(folder: folder, to: parentNode)
	}
	
	func copyFolderBetweenAccounts(folder: Folder, to parentNode: Node) {
		guard let destinationAccount = nodeAccount(parentNode) else {
			return
		}
		
		destinationAccount.addFolder(folder.name ?? "") { result in
			switch result {
			case .success(let destinationFolder):
				for feed in folder.topLevelWebFeeds {
					if let existingFeed = destinationAccount.existingWebFeed(withURL: feed.url) {
						destinationAccount.addWebFeed(existingFeed, to: destinationFolder) { result in
							switch result {
							case .success:
								break
							case .failure(let error):
								NSApplication.shared.presentError(error)
							}
						}
					} else {
						destinationAccount.createWebFeed(url: feed.url, name: feed.nameForDisplay, container: destinationFolder, validateFeed: false) { result in
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
		if draggedNodes != nil {
			return acceptLocalFoldersNodeDrop(outlineView, draggedFolders, parentNode, index)
		} else {
			return acceptLocalFoldersPasteboardDrop(outlineView, draggedFolders, parentNode, index)
		}
	}
	
	func acceptLocalFoldersNodeDrop(_ outlineView: NSOutlineView, _ draggedFolders: Set<PasteboardFolder>, _ parentNode: Node, _ index: Int) -> Bool {
		guard let draggedNodes = draggedNodes else {
			return false
		}
		
		draggedNodes.forEach { node in
			if !sameAccount(node, parentNode) {
				copyFolderBetweenAccounts(node: node, to: parentNode)
			}
		}
		
		return true
	}
	
	func acceptLocalFoldersPasteboardDrop(_ outlineView: NSOutlineView, _ draggedFolders: Set<PasteboardFolder>, _ parentNode: Node, _ index: Int) -> Bool {
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

	func acceptSingleNonLocalFeedDrop(_ outlineView: NSOutlineView, _ draggedFeed: PasteboardWebFeed, _ parentNode: Node, _ index: Int) -> Bool {
		guard nodeIsDropTarget(parentNode), index == NSOutlineViewDropOnItemIndex else {
			return false
		}

		// Show the add-feed sheet.
		if let account = parentNode.representedObject as? Account {
			appDelegate.addWebFeed(draggedFeed.url, name: draggedFeed.editedName ?? draggedFeed.name, account: account, folder: nil)
		} else {
			let account = parentNode.parent?.representedObject as? Account
			let folder = parentNode.representedObject as? Folder
			appDelegate.addWebFeed(draggedFeed.url, name: draggedFeed.editedName ?? draggedFeed.name, account: account, folder: folder)
		}
		
		return true
	}

	func nodeHasChildRepresentingDraggedFeed(_ parentNode: Node, _ draggedFeed: PasteboardWebFeed) -> Bool {
		return nodeHasChildRepresentingAnyDraggedFeed(parentNode, Set([draggedFeed]))
	}

	func nodeRepresentsAnyDraggedFeed(_ node: Node, _ draggedFeeds: Set<PasteboardWebFeed>) -> Bool {
		guard let feed = node.representedObject as? WebFeed else {
			return false
		}
		for draggedFeed in draggedFeeds {
			if feed.url == draggedFeed.url {
				return true
			}
		}
		return false
	}
	
	func sameAccount(_ pasteboardWebFeed: PasteboardWebFeed, _ parentNode: Node) -> Bool {
		if let accountID = pasteboardWebFeed.accountID {
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

	func sameAccount(_ node: Node, _ parentNode: Node) -> Bool {
		if let accountID = nodeAccountID(node) {
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
		} else if let webFeed = node.representedObject as? WebFeed {
			return webFeed.account
		} else {
			return nil
		}

	}
	
	func nodeAccountID(_ node: Node) -> String? {
		return nodeAccount(node)?.accountID
	}
	
	func nodeHasChildRepresentingAnyDraggedFeed(_ parentNode: Node, _ draggedFeeds: Set<PasteboardWebFeed>) -> Bool {
		for node in parentNode.childNodes {
			if nodeRepresentsAnyDraggedFeed(node, draggedFeeds) {
				return true
			}
		}
		return false
	}

	func violatesAccountSpecificBehavior(_ dropTargetNode: Node, _ draggedFeed: PasteboardWebFeed) -> Bool {
		return violatesAccountSpecificBehavior(dropTargetNode, Set([draggedFeed]))
	}
	
	func violatesAccountSpecificBehavior(_ dropTargetNode: Node, _ draggedFeeds: Set<PasteboardWebFeed>) -> Bool {
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

	func violatesDisallowFeedCopyInRootFolder(_ dropTargetNode: Node, _ draggedFeeds: Set<PasteboardWebFeed>) -> Bool {
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

	func violatesDisallowFeedInMultipleFolders(_ dropTargetNode: Node, _ draggedFeeds: Set<PasteboardWebFeed>) -> Bool {
		guard let dropTargetAccount = nodeAccount(dropTargetNode), dropTargetAccount.behaviors.contains(.disallowFeedInMultipleFolders) else {
			return false
		}
		
		for draggedFeed in draggedFeeds {
			if dropTargetAccount.accountID == draggedFeed.accountID {
				if NSApplication.shared.currentEvent?.modifierFlags.contains(.option) ?? false {
					return true
				}
			} else {
				if dropTargetAccount.hasWebFeed(withURL: draggedFeed.url) {
					return true
				}
			}
		}
		
		return false
	}

	func indexWhereDraggedFeedWouldAppear(_ parentNode: Node, _ draggedFeed: PasteboardWebFeed) -> Int {
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
	let pasteboardFeed: PasteboardWebFeed

	init(pasteboardFeed: PasteboardWebFeed) {
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
