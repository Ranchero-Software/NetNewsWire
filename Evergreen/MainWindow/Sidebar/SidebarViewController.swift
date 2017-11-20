//
//  SidebarViewController.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
import RSTree
import Data
import Account
import RSCore

@objc class SidebarViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, UndoableCommandRunner {
    
	@IBOutlet var outlineView: SidebarOutlineView!
	let treeControllerDelegate = SidebarTreeControllerDelegate()
	lazy var treeController: TreeController = {
		TreeController(delegate: treeControllerDelegate)
	}()
    var undoableCommands = [UndoableCommand]()
	private var animatingChanges = false

	//MARK: NSViewController

	override func viewDidLoad() {

		outlineView.sidebarViewController = self
		outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
		outlineView.setDraggingSourceOperationMask(.copy, forLocal: false)

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddFeed(_:)), name: .UserDidAddFeed, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)

		outlineView.reloadData()

		// Always expand all group items on initial display.
		var row = 0
		while(true) {
			guard let item = outlineView.item(atRow: row) else {
				break
			}
			let node = item as! Node
			if node.isGroupItem {
				outlineView.expandItem(item)
			}
			row += 1
		}
	}

	//MARK: Notifications

	@objc dynamic func unreadCountDidChange(_ note: Notification) {
		
		guard let representedObject = note.object else {
			return
		}
		let _ = configureCellsForRepresentedObject(representedObject as AnyObject)
	}

	@objc dynamic func containerChildrenDidChange(_ note: Notification) {

		rebuildTreeAndReloadDataIfNeeded()
	}

	@objc dynamic func batchUpdateDidPerform(_ notification: Notification) {
		
		rebuildTreeAndReloadDataIfNeeded()
	}
	
	@objc dynamic func userDidAddFeed(_ note: Notification) {

		guard let appInfo = note.appInfo, let feed = appInfo.feed else {
			return
		}
		revealAndSelectRepresentedObject(feed)
	}

	// MARK: Actions

	@IBAction func delete(_ sender: AnyObject?) {

		if outlineView.selectionIsEmpty {
			return
		}

		let nodesToDelete = treeController.normalizedSelectedNodes(selectedNodes)
        
        guard let undoManager = undoManager, let deleteCommand = DeleteFromSidebarCommand(nodesToDelete: nodesToDelete, undoManager: undoManager) else {
            return
        }
        
		let selectedRows = outlineView.selectedRowIndexes

		animatingChanges = true
		outlineView.beginUpdates()
		outlineView.removeItems(at: selectedRows, inParent: nil, withAnimation: [.slideDown])
		outlineView.endUpdates()

        runCommand(deleteCommand)
		animatingChanges = false
	}

	// MARK: Navigation
	
	
	func canGoToNextUnread() -> Bool {
		
		if let _ = rowContainingNextUnread() {
			return true
		}
		return false
	}
	
	func goToNextUnread() {
		
		guard let row = rowContainingNextUnread() else {
			assertionFailure("goToNextUnread called before checking if there is a next unread.")
			return
		}
		
		outlineView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
		
		NSApplication.shared.sendAction(NSSelectorFromString("nextUnread:"), to: nil, from: self)
	}
	
	// MARK: NSOutlineViewDelegate
    
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {

		let node = item as! Node

		if node.isGroupItem {
			let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderCell"), owner: self) as! NSTableCellView
			configureGroupCell(cell, node)
			return cell
		}

		let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DataCell"), owner: self) as! SidebarCell
		configure(cell, node)

		return cell
	}

	func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {

		let node = item as! Node
		return node.isGroupItem
	}

	func outlineView(_ outlineView: NSOutlineView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {

		// Don’t allow selecting group items.
		// If any index in IndexSet contains a group item,
		// return the current selection (not a modified version of the proposed selection).

		for index in proposedSelectionIndexes {
			if let node = nodeForRow(index), node.isGroupItem {
				return outlineView.selectedRowIndexes
			}
		}

		return proposedSelectionIndexes
	}

    func outlineViewSelectionDidChange(_ notification: Notification) {

		// TODO: support multiple selection

        let selectedRow = self.outlineView.selectedRow
        
        if selectedRow < 0 || selectedRow == NSNotFound {
            postSidebarSelectionDidChangeNotification(nil)
            return
        }
        
        if let selectedNode = self.outlineView.item(atRow: selectedRow) as? Node {
			postSidebarSelectionDidChangeNotification([selectedNode.representedObject])
        }
    }

	// MARK: NSOutlineViewDataSource

	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		
		return nodeForItem(item as AnyObject?).numberOfChildNodes
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		
        return nodeForItem(item as AnyObject?).childNodes![index]
    }
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		
        return nodeForItem(item as AnyObject?).canHaveChildNodes
	}

	func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {

		let node = nodeForItem(item as AnyObject?)
		if let feed = node.representedObject as? Feed {
			return FeedPasteboardWriter(feed: feed)
		}
		return nil
	}
}

//MARK: - Private

private extension SidebarViewController {
	
	var selectedNodes: [Node] {
		get {
			if let nodes = outlineView.selectedItems as? [Node] {
				return nodes
			}
			return [Node]()
		}
	}
	
	func rebuildTreeAndReloadDataIfNeeded() {
		
		if !animatingChanges && !BatchUpdate.shared.isPerforming {
			treeController.rebuild()
			outlineView.reloadData()
		}
	}
	
	func postSidebarSelectionDidChangeNotification(_ selectedObjects: [AnyObject]?) {

		let appInfo = AppInfo()
		if let objects = selectedObjects {
			appInfo.objects = objects
			DispatchQueue.main.async {
				self.updateUnreadCounts(for: objects)
			}
		}
		appInfo.view = outlineView

		NotificationCenter.default.post(name: .SidebarSelectionDidChange, object: self, userInfo: appInfo.userInfo)
	}

	func updateUnreadCounts(for objects: [AnyObject]) {

		// On selection, update unread counts for folders and feeds.
		// For feeds, actually fetch from database.

		for object in objects {
			if let feed = object as? Feed, let account = feed.account {
				account.updateUnreadCounts(for: Set([feed]))
			}
			else if let folder = object as? Folder, let account = folder.account {
				account.updateUnreadCounts(for: folder.flattenedFeeds())
			}
		}
	}

	func nodeForItem(_ item: AnyObject?) -> Node {

		if item == nil {
			return treeController.rootNode
		}
		return item as! Node
	}

	func nodeForRow(_ row: Int) -> Node? {
		
		if row < 0 || row >= outlineView.numberOfRows {
			return nil
		}
		
		if let node = outlineView.item(atRow: row) as? Node {
			return node
		}
		return nil
	}
	
	func rowHasAtLeastOneUnreadArticle(_ row: Int) -> Bool {
		
		if let oneNode = nodeForRow(row) {
			if let unreadCountProvider = oneNode.representedObject as? UnreadCountProvider {
				if unreadCountProvider.unreadCount > 0 {
					return true
				}
			}
		}
		return false
	}

	func rowContainingNextUnread() -> Int? {
		
		let selectedRow = outlineView.selectedRow
		let numberOfRows = outlineView.numberOfRows
		var row = selectedRow + 1
		
		while (row < numberOfRows) {
			if rowHasAtLeastOneUnreadArticle(row) {
				return row
			}
			row += 1
		}
		
		row = 0
		while (row <= selectedRow) {
			if rowHasAtLeastOneUnreadArticle(row) {
				return row
			}
			row += 1
		}
		
		return nil
	}

	func configure(_ cell: SidebarCell, _ node: Node) {

		cell.objectValue = node
		cell.name = nameFor(node)
		cell.unreadCount = unreadCountFor(node)
		cell.image = imageFor(node)
	}

	func configureGroupCell(_ cell: NSTableCellView, _ node: Node) {

		cell.objectValue = node
		cell.textField?.stringValue = nameFor(node)
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

	func unreadCountFor(_ node: Node) -> Int {

		if let unreadCountProvider = node.representedObject as? UnreadCountProvider {
			return unreadCountProvider.unreadCount
		}
		return 0
	}

	func availableSidebarCells() -> [SidebarCell] {

		var cells = [SidebarCell]()

		outlineView.enumerateAvailableRowViews { (rowView: NSTableRowView, _: Int) -> Void in

			if let oneSidebarCell = rowView.view(atColumn: 0) as? SidebarCell {
				cells += [oneSidebarCell]
			}
		}

		return cells
	}

	func cellsForRepresentedObject(_ representedObject: AnyObject) -> [SidebarCell] {

		let availableCells = availableSidebarCells()
		return availableCells.filter{ (oneSidebarCell) -> Bool in

			guard let oneNode = oneSidebarCell.objectValue as? Node else {
				return false
			}
			return oneNode.representedObject === representedObject
		}
	}

	func configureCellsForRepresentedObject(_ representedObject: AnyObject) -> Bool {

		//Return true if any cells were configured.

		let cells = cellsForRepresentedObject(representedObject)
		if cells.isEmpty {
			return false
		}

		cells.forEach { (oneSidebarCell) in
			guard let oneNode = oneSidebarCell.objectValue as? Node else {
				return
			}
			configure(oneSidebarCell, oneNode)
			oneSidebarCell.needsDisplay = true
			oneSidebarCell.needsLayout = true
		}
		return true
	}

	@discardableResult
	func revealAndSelectRepresentedObject(_ representedObject: AnyObject) -> Bool {

		return outlineView.revealAndSelectRepresentedObject(representedObject, treeController)
	}
	
	func folderParentForNode(_ node: Node) -> Container? {
		
		if let folder = node.parent?.representedObject as? Container {
			return folder
		}
		if let feed = node.representedObject as? Feed {
			return feed.account
		}
		if let folder = node.representedObject as? Folder {
			return folder.account
		}
		return nil
	}
	
	func deleteItemForNode(_ node: Node) {
		
//		if let folder = folderParentForNode(node) {
//			folder.deleteItems([node.representedObject])
//		}
	}
	
	func deleteItemsForNodes(_ nodes: [Node]) {
		
		nodes.forEach { (oneNode) in
			
			deleteItemForNode(oneNode)
		}
	}
	
}

