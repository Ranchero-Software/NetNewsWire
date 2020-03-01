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
	func unreadCount(for: AnyObject) -> Int
}

@objc class SidebarViewController: NSViewController, NSOutlineViewDelegate, NSMenuDelegate, UndoableCommandRunner {
    
	@IBOutlet var outlineView: SidebarOutlineView!

	weak var delegate: SidebarDelegate?

	private let rebuildTreeAndRestoreSelectionQueue = CoalescingQueue(name: "Rebuild Tree Queue", interval: 0.5)
	let treeControllerDelegate = WebFeedTreeControllerDelegate()
	lazy var treeController: TreeController = {
		return TreeController(delegate: treeControllerDelegate)
	}()
	lazy var dataSource: SidebarOutlineDataSource = {
		return SidebarOutlineDataSource(treeController: treeController)
	}()
	var isReadFiltered: Bool {
		return treeControllerDelegate.isReadFiltered
	}

    var undoableCommands = [UndoableCommand]()
	private var animatingChanges = false
	private var sidebarCellAppearance: SidebarCellAppearance!

	var renameWindowController: RenameWindowController?

	var selectedObjects: [AnyObject] {
		return selectedNodes.representedObjects()
	}

	// MARK: - NSViewController

	override func viewDidLoad() {
		sidebarCellAppearance = SidebarCellAppearance(fontSize: AppDefaults.sidebarFontSize)

		outlineView.dataSource = dataSource
		outlineView.doubleAction = #selector(doubleClickedSidebar(_:))
		outlineView.setDraggingSourceOperationMask([.move, .copy], forLocal: true)
		outlineView.registerForDraggedTypes([WebFeedPasteboardWriter.webFeedUTIInternalType, WebFeedPasteboardWriter.webFeedUTIType, .URL, .string])

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddFeed(_:)), name: .UserDidAddFeed, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedSettingDidChange(_:)), name: .WebFeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(downloadArticlesDidUpdateUnreadCounts(_:)), name: .DownloadArticlesDidUpdateUnreadCounts, object: nil)

		outlineView.reloadData()

		// Always expand all group items on first run.
		if AppDefaults.isFirstRun {
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

		outlineView.autosaveExpandedItems = true

	}

	// MARK: - Notifications

	@objc func unreadCountDidChange(_ note: Notification) {
		guard let representedObject = note.object else {
			return
		}
		
		if let timelineViewController = representedObject as? TimelineViewController {
			configureUnreadCountForCellsForRepresentedObjects(timelineViewController.representedObjects)
		} else {
			configureUnreadCountForCellsForRepresentedObjects([representedObject as AnyObject])
		}

		if let feed = representedObject as? Feed, isReadFiltered, feed.unreadCount > 0 {
			addTreeControllerToFilterExceptions()
			queueRebuildTreeAndRestoreSelection()
		}
	}

	@objc func containerChildrenDidChange(_ note: Notification) {
		rebuildTreeAndRestoreSelection()
	}

	@objc func accountsDidChange(_ notification: Notification) {
		rebuildTreeAndRestoreSelection()
	}
	
	@objc func accountStateDidChange(_ notification: Notification) {
		rebuildTreeAndRestoreSelection()
	}

	@objc func batchUpdateDidPerform(_ notification: Notification) {
		rebuildTreeAndRestoreSelection()
	}
	
	@objc func userDidAddFeed(_ notification: Notification) {
		guard let feed = notification.userInfo?[UserInfoKey.webFeed] else {
			return
		}
		revealAndSelectRepresentedObject(feed as AnyObject)
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		applyToAvailableCells(configureFavicon)
	}

	@objc func webFeedSettingDidChange(_ note: Notification) {
		guard let webFeed = note.object as? WebFeed, let key = note.userInfo?[WebFeed.WebFeedSettingUserInfoKey] as? String else {
			return
		}
		if key == WebFeed.WebFeedSettingKey.homePageURL || key == WebFeed.WebFeedSettingKey.faviconURL {
			configureCellsForRepresentedObject(webFeed)
		}
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
		guard let feed = note.userInfo?[UserInfoKey.webFeed] else {
			return
		}
		revealAndSelectRepresentedObject(feed as AnyObject)
	}
	
	@objc func downloadArticlesDidUpdateUnreadCounts(_ note: Notification) {
		rebuildTreeAndRestoreSelection()
	}
	
	// MARK: - Actions

	@IBAction func delete(_ sender: AnyObject?) {
		if outlineView.selectionIsEmpty {
			return
		}
		deleteNodes(selectedNodes)
	}
	
	@IBAction func doubleClickedSidebar(_ sender: Any?) {
		guard outlineView.clickedRow == outlineView.selectedRow else {
			return
		}
		openInBrowser(sender)
	}

	@IBAction func openInBrowser(_ sender: Any?) {
		guard let feed = singleSelectedWebFeed, let homePageURL = feed.homePageURL else {
			return
		}
		Browser.open(homePageURL)
	}

	@IBAction func gotoToday(_ sender: Any?) {
		selectFeed(SmartFeedsController.shared.todayFeed)
		focus()
	}

	@IBAction func gotoAllUnread(_ sender: Any?) {
		selectFeed(SmartFeedsController.shared.unreadFeed)
		focus()
	}

	@IBAction func gotoStarred(_ sender: Any?) {
		selectFeed(SmartFeedsController.shared.starredFeed)
		focus()
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
		outlineView.window?.makeFirstResponderUnlessDescendantIsFirstResponder(outlineView)
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

	// MARK: - NSMenuDelegate
	
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
    }

	func expandRelevantFoldersForAccount(_ account: Account) {
		guard let folders = account.folders else { return }

		guard let autosaveName = outlineView.autosaveName else { return }

		let defaultsKey = "NSOutlineView Items \(autosaveName)"

		guard let savedExpandedItems = UserDefaults.standard.array(forKey: defaultsKey) as? [[AnyHashable: AnyHashable]] else { return }

		let expandedIdentifiers = savedExpandedItems.reduce(into: Set<ContainerIdentifier>()) { (result, dict) in
			guard let identifier = ContainerIdentifier(userInfo: dict) else { return }
			result.insert(identifier)
		}

		for folder in folders {
			guard let folderID = folder.containerID else { continue }

			if expandedIdentifiers.contains(folderID) {
				outlineView.expandItem(treeController.nodeInTreeRepresentingObject(folder))
			}
		}
	}

	func outlineViewItemDidExpand(_ notification: Notification) {
		guard let item = notification.userInfo?["NSObject"] as? Node,
			let account = nodeForItem(item).representedObject as? Account else { return }

		expandRelevantFoldersForAccount(account)
	}

	//MARK: - Node Manipulation
	
	func deleteNodes(_ nodes: [Node]) {
		let nodesToDelete = treeController.normalizedSelectedNodes(nodes)
		
		guard let undoManager = undoManager, let deleteCommand = DeleteCommand(nodesToDelete: nodesToDelete, undoManager: undoManager, errorHandler: ErrorHandler.present) else {
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
	
	func selectFeed(_ feed: Feed) {
		if isReadFiltered, let feedID = feed.feedID {
			self.treeControllerDelegate.addFilterException(feedID)
			
			if let webFeed = feed as? WebFeed, let account = webFeed.account {
				let parentFolder = account.sortedFolders?.first(where: { $0.objectIsChild(webFeed) })
				if let parentFolderFeedID = parentFolder?.feedID {
					self.treeControllerDelegate.addFilterException(parentFolderFeedID)
				}
			}
			
			addTreeControllerToFilterExceptions()
			rebuildTreeAndRestoreSelection()
		}

		revealAndSelectRepresentedObject(feed as AnyObject)
	}

	func deepLinkRevealAndSelect(for userInfo: [AnyHashable : Any]) {
		guard let accountNode = findAccountNode(userInfo),
			let feedNode = findFeedNode(userInfo, beginningAt: accountNode),
			let feed = feedNode.representedObject as? Feed else {
			return
		}
		selectFeed(feed)
	}

	func toggleReadFilter() {
		if treeControllerDelegate.isReadFiltered {
			treeControllerDelegate.isReadFiltered = false
		} else {
			treeControllerDelegate.isReadFiltered = true
		}
		rebuildTreeAndRestoreSelection()
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
	
	var accountNodes: [Account] {
		return treeController.rootNode.childNodes.compactMap { $0.representedObject as? Account }
	}
	
	var selectedNodes: [Node] {
		if let nodes = outlineView.selectedItems as? [Node] {
			return nodes
		}
		return [Node]()
	}
	
	var selectedFeeds: [Feed] {
		selectedNodes.compactMap { $0.representedObject as? Feed }
	}

	var singleSelectedNode: Node? {
		guard selectedNodes.count == 1 else {
			return nil
		}
		return selectedNodes.first!
	}

	var singleSelectedWebFeed: WebFeed? {
		guard let node = singleSelectedNode else {
			return nil
		}
		return node.representedObject as? WebFeed
	}
	
	func addAllSelectedToFilterExceptions() {
		selectedFeeds.forEach { addToFilterExeptionsIfNecessary($0) }
	}
	
	func addToFilterExeptionsIfNecessary(_ feed: Feed?) {
		if isReadFiltered, let feedID = feed?.feedID {
			if feed is SmartFeed {
				treeControllerDelegate.addFilterException(feedID)
			} else if let folderFeed = feed as? Folder {
				if folderFeed.account?.existingFolder(withID: folderFeed.folderID) != nil {
					treeControllerDelegate.addFilterException(feedID)
				}
			} else if let webFeed = feed as? WebFeed {
				if webFeed.account?.existingWebFeed(withWebFeedID: webFeed.webFeedID) != nil {
					treeControllerDelegate.addFilterException(feedID)
					addParentFolderToFilterExceptions(webFeed)
				}
			}
		}
	}
	
	func addParentFolderToFilterExceptions(_ feed: Feed) {
		guard let node = treeController.rootNode.descendantNodeRepresentingObject(feed as AnyObject),
			let folder = node.parent?.representedObject as? Folder,
			let folderFeedID = folder.feedID else {
				return
		}
		
		treeControllerDelegate.addFilterException(folderFeedID)
	}
	

	func queueRebuildTreeAndRestoreSelection() {
		rebuildTreeAndRestoreSelectionQueue.add(self, #selector(rebuildTreeAndRestoreSelection))
	}
	
	@objc func rebuildTreeAndRestoreSelection() {
		let savedAccounts = accountNodes
		let savedSelection = selectedNodes
		
		rebuildTreeAndReloadDataIfNeeded()
		restoreSelection(to: savedSelection, sendNotificationIfChanged: true)
		
		// Automatically expand any new or newly active accounts
		AccountManager.shared.activeAccounts.forEach { account in
			if !savedAccounts.contains(account) {
				let accountNode = treeController.nodeInTreeRepresentingObject(account)
				outlineView.expandItem(accountNode)
			}
		}
		
	}
	
	func rebuildTreeAndReloadDataIfNeeded() {
		if !animatingChanges && !BatchUpdate.shared.isPerforming {
			addAllSelectedToFilterExceptions()
			treeController.rebuild()
			treeControllerDelegate.resetFilterExceptions()
			outlineView.reloadData()
		}
	}
	
	func addTreeControllerToFilterExceptions() {
		treeController.visitNodes(addTreeControllerToFilterExceptionsVisitor(node:))
	}

	func addTreeControllerToFilterExceptionsVisitor(node: Node) {
		if let feed = node.representedObject as? Feed, let feedID = feed.feedID {
			treeControllerDelegate.addFilterException(feedID)
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
			if let feed = object as? WebFeed, let account = feed.account {
				account.updateUnreadCounts(for: Set([feed]))
			}
			else if let folder = object as? Folder, let account = folder.account {
				account.updateUnreadCounts(for: folder.flattenedWebFeeds())
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

	func findAccountNode(_ userInfo: [AnyHashable : Any]?) -> Node? {
		guard let accountID = userInfo?[ArticlePathKey.accountID] as? String else {
			return nil
		}
		
		if let node = treeController.rootNode.descendantNode(where: { ($0.representedObject as? Account)?.accountID == accountID }) {
			return node
		}

		guard let accountName = userInfo?[ArticlePathKey.accountName] as? String else {
			return nil
		}

		if let node = treeController.rootNode.descendantNode(where: { ($0.representedObject as? Account)?.nameForDisplay == accountName }) {
			return node
		}

		return nil
	}
	
	func findFeedNode(_ userInfo: [AnyHashable : Any]?, beginningAt startingNode: Node) -> Node? {
		guard let webFeedID = userInfo?[ArticlePathKey.webFeedID] as? String else {
			return nil
		}
		if let node = startingNode.descendantNode(where: { ($0.representedObject as? WebFeed)?.webFeedID == webFeedID }) {
			return node
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
		cell.image = imageFor(node)?.image
	}

	func configureGroupCell(_ cell: NSTableCellView, _ node: Node) {
		cell.textField?.stringValue = nameFor(node)
	}

	func imageFor(_ node: Node) -> IconImage? {
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
		// If this node is the one and only selection,
		// then the unread count comes from the timeline.
		// This ensures that any transients in the timeline
		// are accounted for in the unread count.
		if nodeShouldGetUnreadCountFromTimeline(node) {
			return delegate?.unreadCount(for: node.representedObject) ?? 0
		}

		if let unreadCountProvider = node.representedObject as? UnreadCountProvider {
			return unreadCountProvider.unreadCount
		}
		return 0
	}

	func nodeShouldGetUnreadCountFromTimeline(_ node: Node) -> Bool {
		// Only if it’s selected and it’s the only node selected.
		return selectedNodes.count == 1 && selectedNodes.first! === node
	}

	func nodeRepresentsTodayFeed(_ node: Node) -> Bool {
		guard let smartFeed = node.representedObject as? SmartFeed else {
			return false
		}
		return smartFeed === SmartFeedsController.shared.todayFeed
	}

	func cellForRowView(_ rowView: NSTableRowView) -> SidebarCell? {
		return rowView.view(atColumn: 0) as? SidebarCell
	}

	func applyToAvailableCells(_ completion: (SidebarCell, Node) -> Void) {
		outlineView.enumerateAvailableRowViews { (rowView: NSTableRowView, row: Int) -> Void in
			guard let cell = cellForRowView(rowView), let node = nodeForRow(row) else {
				return
			}
			completion(cell, node)
		}
	}

	func applyToCellsForRepresentedObject(_ representedObject: AnyObject, _ completion: (SidebarCell, Node) -> Void) {
		applyToAvailableCells { (cell, node) in
			if node.representsSidebarObject(representedObject) {
				completion(cell, node)
			}
		}
	}

	func configureCellsForRepresentedObject(_ representedObject: AnyObject) {
		applyToCellsForRepresentedObject(representedObject, configure)
	}

	func configureUnreadCountForCellsForRepresentedObjects(_ representedObjects: [AnyObject]?) {
		guard let representedObjects = representedObjects else {
			return
		}
		for object in representedObjects {
			applyToCellsForRepresentedObject(object, configureUnreadCount)
		}
	}

	@discardableResult
	func revealAndSelectRepresentedObject(_ representedObject: AnyObject) -> Bool {
		return outlineView.revealAndSelectRepresentedObject(representedObject, treeController)
	}
}

private extension Node {

	func representsSidebarObject(_ object: AnyObject) -> Bool {
		if representedObject === object {
			return true
		}
		if let feed1 = object as? WebFeed, let feed2 = representedObject as? WebFeed {
			return feed1 == feed2
		}
		return false
	}
}
