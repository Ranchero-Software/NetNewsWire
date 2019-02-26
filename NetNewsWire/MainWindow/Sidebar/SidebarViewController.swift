//
//  SidebarViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSTree
import Articles
import Account
import RSCore

protocol SidebarDelegate: class {
	func sidebarSelectionDidChange(_: SidebarViewController, selectedObjects: [AnyObject]?)
}

@objc class SidebarViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, NSMenuDelegate, UndoableCommandRunner {
    
	@IBOutlet var outlineView: SidebarOutlineView!

	weak var delegate: SidebarDelegate?

	let treeControllerDelegate = SidebarTreeControllerDelegate()
	lazy var treeController: TreeController = {
		return TreeController(delegate: treeControllerDelegate)
	}()
	lazy var dataSource: SidebarOutlineDataSource = {
		return SidebarOutlineDataSource(treeController: treeController)
	}()

    var undoableCommands = [UndoableCommand]()
	private var animatingChanges = false
	private var sidebarCellAppearance: SidebarCellAppearance!

	var renameWindowController: RenameWindowController?

	var selectedObjects: [AnyObject] {
		return selectedNodes.representedObjects()
	}

	// MARK: - NSViewController

	override func viewDidLoad() {

		sidebarCellAppearance = SidebarCellAppearance(theme: appDelegate.currentTheme, fontSize: AppDefaults.sidebarFontSize)

		outlineView.dataSource = dataSource
		outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
		outlineView.setDraggingSourceOperationMask(.copy, forLocal: false)
		outlineView.registerForDraggedTypes([FeedPasteboardWriter.feedUTIInternalType, FeedPasteboardWriter.feedUTIType, .URL, .string])

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddFeed(_:)), name: .UserDidAddFeed, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .FeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidRequestSidebarSelection(_:)), name: .UserDidRequestSidebarSelection, object: nil)

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

	// MARK: State Restoration

//	private static let stateRestorationSelectedRowIndexes = "selectedRowIndexes"
//
//	override func encodeRestorableState(with coder: NSCoder) {
//
//		super.encodeRestorableState(with: coder)
//
//		coder.encode(outlineView.selectedRowIndexes, forKey: SidebarViewController.stateRestorationSelectedRowIndexes)
//	}
//
//	override func restoreState(with coder: NSCoder) {
//
//		super.restoreState(with: coder)
//
//		if let restoredRowIndexes = coder.decodeObject(of: [NSIndexSet.self], forKey: SidebarViewController.stateRestorationSelectedRowIndexes) as? IndexSet {
//			outlineView.selectRowIndexes(restoredRowIndexes, byExtendingSelection: false)
//		}
//	}

	// MARK: - Notifications

	@objc func unreadCountDidChange(_ note: Notification) {
		
		guard let representedObject = note.object else {
			return
		}
		configureUnreadCountForCellsForRepresentedObject(representedObject as AnyObject)
	}

	@objc func containerChildrenDidChange(_ note: Notification) {
		rebuildTreeAndRestoreSelection()
	}

	@objc func batchUpdateDidPerform(_ notification: Notification) {
		rebuildTreeAndRestoreSelection()
	}
	
	@objc func userDidAddFeed(_ notification: Notification) {

		guard let feed = notification.userInfo?[UserInfoKey.feed] else {
			return
		}
		revealAndSelectRepresentedObject(feed as AnyObject)
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {

		applyToAvailableCells(configureFavicon)
	}

	@objc func feedSettingDidChange(_ note: Notification) {

		guard let feed = note.object as? Feed else {
			return
		}
		configureCellsForRepresentedObject(feed)
	}

	@objc func displayNameDidChange(_ note: Notification) {

		guard let object = note.object else {
			return
		}
		let savedSelection = selectedNodes
		rebuildTreeAndReloadDataIfNeeded()
		configureCellsForRepresentedObject(object as AnyObject)
		restoreSelection(to: savedSelection, sendNotificationIfChanged: true)
	}

	@objc func userDidRequestSidebarSelection(_ note: Notification) {
		
		guard let feed = note.userInfo?[UserInfoKey.feed] else {
			return
		}
		revealAndSelectRepresentedObject(feed as AnyObject)
	}
	
	// MARK: - Actions

	@IBAction func delete(_ sender: AnyObject?) {

		if outlineView.selectionIsEmpty {
			return
		}
		deleteNodes(selectedNodes)
	}

	@IBAction func openInBrowser(_ sender: Any?) {

		guard let feed = singleSelectedFeed, let homePageURL = feed.homePageURL else {
			return
		}
		Browser.open(homePageURL)
	}

	@IBAction func gotoToday(_ sender: Any?) {

		outlineView.revealAndSelectRepresentedObject(SmartFeedsController.shared.todayFeed, treeController)
	}

	@IBAction func gotoAllUnread(_ sender: Any?) {

		outlineView.revealAndSelectRepresentedObject(SmartFeedsController.shared.unreadFeed, treeController)
	}

	@IBAction func gotoStarred(_ sender: Any?) {

		outlineView.revealAndSelectRepresentedObject(SmartFeedsController.shared.starredFeed, treeController)
	}

	@IBAction func copy(_ sender: Any?) {

		NSPasteboard.general.copyObjects(selectedObjects)
	}

	// MARK: - Navigation
	
	func canGoToNextUnread() -> Bool {
		
		if let _ = nextSelectableRowWithUnreadArticle() {
			return true
		}
		return false
	}
	
	func goToNextUnread() {
		
		guard let row = nextSelectableRowWithUnreadArticle() else {
			assertionFailure("goToNextUnread called before checking if there is a next unread.")
			return
		}
		
		NSCursor.setHiddenUntilMouseMoves(true)
		outlineView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
		outlineView.scrollTo(row: row)
		
	}

	func focus() {

		guard let window = outlineView.window else {
			return
		}
		window.makeFirstResponderUnlessDescendantIsFirstResponder(outlineView)
	}

	// MARK: - Contextual Menu

	func contextualMenuForSelectedObjects() -> NSMenu? {

		return menu(for: selectedObjects)
	}

	func contextualMenuForClickedRows() -> NSMenu? {

		let row = outlineView.clickedRow
		guard row != -1, let node = nodeForRow(row) else {
			return nil
		}

		if outlineView.selectedRowIndexes.contains(row) {
			// If the clickedRow is part of the selected rows, then do a contextual menu for all the selected rows.
			return contextualMenuForSelectedObjects()
		}
		
		let object = node.representedObject
		return menu(for: [object])
	}

	// MARK: NSMenuDelegate
	
	public func menuNeedsUpdate(_ menu: NSMenu) {
		menu.removeAllItems()
		guard let contextualMenu = contextualMenuForClickedRows() else {
			return
		}
		menu.takeItems(from: contextualMenu)
	}


	// MARK: - NSOutlineViewDelegate
    
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

	func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {

		return !self.outlineView(outlineView, isGroupItem: item)
	}

    func outlineViewSelectionDidChange(_ notification: Notification) {
		selectionDidChange(selectedObjects.isEmpty ? nil : selectedObjects)
//		self.invalidateRestorableState()
    }

	//MARK: - Node Manipulation
	
	func deleteNodes(_ nodes: [Node]) {
		
		let nodesToDelete = treeController.normalizedSelectedNodes(nodes)
		
		guard let undoManager = undoManager, let deleteCommand = DeleteFromSidebarCommand(nodesToDelete: nodesToDelete, treeController: treeController, undoManager: undoManager) else {
			return
		}
		
		animatingChanges = true
		outlineView.beginUpdates()
		
		let indexSetsGroupedByParent = Node.indexSetsGroupedByParent(nodesToDelete)
		for (parent, indexSet) in indexSetsGroupedByParent {
			outlineView.removeItems(at: indexSet, inParent: parent.isRoot ? nil : parent, withAnimation: [.slideDown])
		}
		
		outlineView.endUpdates()
		
		runCommand(deleteCommand)
		animatingChanges = false
	}

	// MARK: - API

	func rebuildTreeAndRestoreSelection() {
		let savedSelection = selectedNodes
		rebuildTreeAndReloadDataIfNeeded()
		restoreSelection(to: savedSelection, sendNotificationIfChanged: true)
	}
}

// MARK: - NSUserInterfaceValidations

extension SidebarViewController: NSUserInterfaceValidations {

	func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {

		if item.action == #selector(copy(_:)) {
			return NSPasteboard.general.canCopyAtLeastOneObject(selectedObjects)
		}
		return true
	}
}

//MARK: - Private

private extension SidebarViewController {
	
	var selectedNodes: [Node] {
		if let nodes = outlineView.selectedItems as? [Node] {
			return nodes
		}
		return [Node]()
	}

	var singleSelectedNode: Node? {
		guard selectedNodes.count == 1 else {
			return nil
		}
		return selectedNodes.first!
	}

	var singleSelectedFeed: Feed? {
		guard let node = singleSelectedNode else {
			return nil
		}
		return node.representedObject as? Feed
	}

	func rebuildTreeAndReloadDataIfNeeded() {
		
		if !animatingChanges && !BatchUpdate.shared.isPerforming {
			treeController.rebuild()
			outlineView.reloadData()
		}
	}

	func restoreSelection(to nodes: [Node], sendNotificationIfChanged: Bool) {
		if selectedNodes == nodes { // Nothing to do?
			return
		}

		var indexes = IndexSet()
		for node in nodes {
			let row = outlineView.row(forItem: node as Any)
			if row > -1 {
				indexes.insert(row)
			}
		}

		outlineView.selectRowIndexes(indexes, byExtendingSelection: false)

		if selectedNodes != nodes && sendNotificationIfChanged {
			selectionDidChange(selectedObjects)
		}
	}

	func selectionDidChange(_ selectedObjects: [AnyObject]?) {
		delegate?.sidebarSelectionDidChange(self, selectedObjects: selectedObjects)
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

	func rowIsGroupItem(_ row: Int) -> Bool {

		if let node = nodeForRow(row), outlineView.isGroupItem(node) {
			return true
		}
		return false
	}

	func nextSelectableRowWithUnreadArticle() -> Int? {

		// Skip group items, because they should never be selected.

		let selectedRow = outlineView.selectedRow
		let numberOfRows = outlineView.numberOfRows
		var row = selectedRow + 1
		
		while (row < numberOfRows) {
			if rowHasAtLeastOneUnreadArticle(row) && !rowIsGroupItem(row) {
				return row
			}
			row += 1
		}
		
		row = 0
		while (row <= selectedRow) {
			if rowHasAtLeastOneUnreadArticle(row) && !rowIsGroupItem(row) {
				return row
			}
			row += 1
		}
		
		return nil
	}

	func configure(_ cell: SidebarCell, _ node: Node) {
		cell.cellAppearance = sidebarCellAppearance
		cell.name = nameFor(node)
		configureUnreadCount(cell, node)
		configureFavicon(cell, node)
		cell.shouldShowImage = node.representedObject is SmallIconProvider
	}

	func configureUnreadCount(_ cell: SidebarCell, _ node: Node) {

		cell.unreadCount = unreadCountFor(node)
	}

	func configureFavicon(_ cell: SidebarCell, _ node: Node) {

		cell.image = imageFor(node)
	}

	func configureGroupCell(_ cell: NSTableCellView, _ node: Node) {
		cell.textField?.stringValue = nameFor(node)
	}

	func imageFor(_ node: Node) -> NSImage? {

		if let smallIconProvider = node.representedObject as? SmallIconProvider {
			return smallIconProvider.smallIcon
		}
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

	func cellForRowView(_ rowView: NSTableRowView) -> SidebarCell? {

		return rowView.view(atColumn: 0) as? SidebarCell
	}

	func applyToAvailableCells(_ callback: (SidebarCell, Node) -> Void) {

		outlineView.enumerateAvailableRowViews { (rowView: NSTableRowView, row: Int) -> Void in

			guard let cell = cellForRowView(rowView), let node = nodeForRow(row) else {
				return
			}
			callback(cell, node)
		}
	}

	func applyToCellsForRepresentedObject(_ representedObject: AnyObject, _ callback: (SidebarCell, Node) -> Void) {

		applyToAvailableCells { (cell, node) in
			if node.representedObject === representedObject {
				callback(cell, node)
			}
		}
	}

	func configureCellsForRepresentedObject(_ representedObject: AnyObject) {

		applyToCellsForRepresentedObject(representedObject, configure)
	}

	func configureUnreadCountForCellsForRepresentedObject(_ representedObject: AnyObject) {

		applyToCellsForRepresentedObject(representedObject, configureUnreadCount)
	}

	@discardableResult
	func revealAndSelectRepresentedObject(_ representedObject: AnyObject) -> Bool {

		return outlineView.revealAndSelectRepresentedObject(representedObject, treeController)
	}
}


