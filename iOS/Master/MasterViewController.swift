//
//  MasterViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import Articles
import RSCore
import RSTree

class MasterViewController: UITableViewController, UndoableCommandRunner {

	var undoableCommands = [UndoableCommand]()
	var animatingChanges = false
	
	var expandedNodes = [Node]()
	var shadowTable = [[Node]]()
	
	let treeControllerDelegate = FeedTreeControllerDelegate()
	lazy var treeController: TreeController = {
		return TreeController(delegate: treeControllerDelegate)
	}()
	
	override var canBecomeFirstResponder: Bool {
		return true
	}

	override func viewDidLoad() {

		super.viewDidLoad()

		navigationItem.rightBarButtonItem = editButtonItem
		
		tableView.register(MasterTableViewSectionHeader.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .FeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddFeed(_:)), name: .UserDidAddFeed, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)

		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
		// Default the sections to expanded and set up the shadow table
		for section in treeController.rootNode.childNodes {
			expandedNodes.append(section)
			shadowTable.append([Node]())
		}
		
		rebuildShadowTable()
		
	}

	override func viewWillAppear(_ animated: Bool) {
		clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
		super.viewWillAppear(animated)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		becomeFirstResponder()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		resignFirstResponder()
	}

	// MARK: Notifications
	
	@objc dynamic func progressDidChange(_ notification: Notification) {
		if AccountManager.shared.combinedRefreshProgress.isComplete {
			refreshControl?.endRefreshing()
		} else {
			refreshControl?.beginRefreshing()
		}
	}

	@objc func containerChildrenDidChange(_ note: Notification) {
		rebuildBackingStoresAndReloadDataIfNeeded()
	}
	
	@objc func batchUpdateDidPerform(_ notification: Notification) {
		rebuildBackingStoresAndReloadDataIfNeeded()
	}
	
	@objc func unreadCountDidChange(_ note: Notification) {
		
		guard let representedObject = note.object else {
			return
		}
		
		if let account = representedObject as? Account {
			if let node = treeController.rootNode.childNodeRepresentingObject(account) {
				let sectionIndex = treeController.rootNode.indexOfChild(node)!
				let headerView = tableView.headerView(forSection: sectionIndex) as! MasterTableViewSectionHeader
				headerView.unreadCount = account.unreadCount
			}
			return
		}
		
		configureUnreadCountForCellsForRepresentedObject(representedObject as AnyObject)
		
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		applyToAvailableCells(configureFavicon)
	}

	@objc func feedSettingDidChange(_ note: Notification) {
		
		guard let feed = note.object as? Feed, let key = note.userInfo?[Feed.FeedSettingUserInfoKey] as? String else {
			return
		}
		
		if key == Feed.FeedSettingKey.homePageURL || key == Feed.FeedSettingKey.faviconURL {
			configureCellsForRepresentedObject(feed)
		}
		
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		
		guard let object = note.object else {
			return
		}
		
		rebuildBackingStoresAndReloadDataIfNeeded()
		configureCellsForRepresentedObject(object as AnyObject)
		
	}

	@objc func userDidAddFeed(_ notification: Notification) {
		
		guard let feed = notification.userInfo?[UserInfoKey.feed],
			let node = treeController.rootNode.descendantNodeRepresentingObject(feed as AnyObject) else {
				return
		}
		
		if let indexPath = indexPathFor(node) {
			tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
			return
		}
	
		// It wasn't already visable, so expand its folder and try again
		guard let parent = node.parent, let indexPath = indexPathFor(parent) else {
			return
		}
		
		expand(indexPath)

		if let indexPath = indexPathFor(node) {
			tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
		}

	}

	// MARK: Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return treeController.rootNode.numberOfChildNodes
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return shadowTable[section].count
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		
		guard let nameProvider = treeController.rootNode.childAtIndex(section)?.representedObject as? DisplayNameProvider else {
			return nil
		}
		
		let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! MasterTableViewSectionHeader
		headerView.name = nameProvider.nameForDisplay
		
		if let account = treeController.rootNode.childAtIndex(section)?.representedObject as? Account {
			headerView.unreadCount = account.unreadCount
		} else {
			headerView.unreadCount = 0
		}
		
		headerView.tag = section
		
		let tap = UITapGestureRecognizer(target: self, action:#selector(self.toggleSectionHeader(_:)))
		headerView.addGestureRecognizer(tap)

		return headerView
		
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterTableViewCell
		
		guard let node = nodeFor(indexPath) else {
			return cell
		}
		
		configure(cell, node)
		return cell

	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		guard let node = nodeFor(indexPath), !(node.representedObject is PseudoFeed) else {
			return false
		}
		return true
	}
	
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		
		// Set up the delete action
		let deleteTitle = NSLocalizedString("Delete", comment: "Delete")
		let deleteAction = UIContextualAction(style: .normal, title: deleteTitle) { [weak self] (action, view, completionHandler) in
			self?.delete(indexPath: indexPath)
			completionHandler(true)
		}
		
		deleteAction.backgroundColor = UIColor.red
		
		// Set up the rename action
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIContextualAction(style: .normal, title: renameTitle) { [weak self] (action, view, completionHandler) in
			self?.rename(indexPath: indexPath)
			completionHandler(true)
		}
		
		renameAction.backgroundColor = UIColor.gray
		
		return UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
		
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		guard let node = nodeFor(indexPath) else {
			assertionFailure()
			return
		}
		
		let timeline = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
		
		if let pseudoFeed = node.representedObject as? PseudoFeed {
			timeline.title = pseudoFeed.nameForDisplay
			timeline.representedObjects = [pseudoFeed]
		}
		
		if let folder = node.representedObject as? Folder {
			timeline.title = folder.nameForDisplay
			timeline.representedObjects = [folder]
		}
		
		if let feed = node.representedObject as? Feed {
			timeline.title = feed.nameForDisplay
			timeline.representedObjects = [feed]
		}
		
		self.navigationController?.pushViewController(timeline, animated: true)

	}

	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		guard let node = nodeFor(indexPath) else {
			return false
		}
		return node.representedObject is Feed
	}
	
	override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

		// Adjust the index path so that it will never be in the smart feeds area
		let destIndexPath: IndexPath = {
			if proposedDestinationIndexPath.section == 0 {
				return IndexPath(row: 0, section: 1)
			}
			return proposedDestinationIndexPath
		}()
		
		guard let draggedNode = nodeFor(sourceIndexPath), let destNode = nodeFor(destIndexPath), let parentNode = destNode.parent else {
			assertionFailure("This should never happen")
			return sourceIndexPath
		}
		
		// If this is a folder and isn't expanded or doesn't have any entries, let the users drop on it
		if destNode.representedObject is Folder && (destNode.numberOfChildNodes == 0 || !expandedNodes.contains(destNode)) {
			let movementAdjustment = sourceIndexPath > proposedDestinationIndexPath ? 1 : 0
			return IndexPath(row: destIndexPath.row + movementAdjustment, section: destIndexPath.section)
		}
		
		// If we are dragging around in the same container, just return the original source
		if parentNode.childNodes.contains(draggedNode) {
			return sourceIndexPath
		}
		
		// Suggest to the user the best place to drop the feed
		// Revisit if the tree controller can ever be sorted in some other way.
		let nodes = parentNode.childNodes + [draggedNode]
		var sortedNodes = nodes.sortedAlphabeticallyWithFoldersAtEnd()
		let index = sortedNodes.firstIndex(of: draggedNode)!

		if index == 0 {
			if parentNode.representedObject is Account {
				return IndexPath(row: 0, section: destIndexPath.section)
			} else {
				return indexPathFor(parentNode)!
			}
		} else {
			sortedNodes.remove(at: sortedNodes.firstIndex(of: draggedNode)!)
			let movementAdjustment = sourceIndexPath < proposedDestinationIndexPath ? 1 : 0
			return indexPathFor(sortedNodes[index - movementAdjustment])!
		}
		
	}
	
	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {

		guard let sourceNode = nodeFor(sourceIndexPath), let feed = sourceNode.representedObject as? Feed else {
			return
		}

		// Based on the drop we have to determine a node to start looking for a parent container.
		let destNode: Node = {
			if destinationIndexPath.row == 0 {
				return treeController.rootNode.childAtIndex(destinationIndexPath.section)!
			} else {
				let movementAdjustment = sourceIndexPath > destinationIndexPath ? 1 : 0
				let adjustedDestIndexPath = IndexPath(row: destinationIndexPath.row - movementAdjustment, section: destinationIndexPath.section)
				return nodeFor(adjustedDestIndexPath)!
			}
		}()

		// Now we start looking for the parent container
		let destParentNode: Node? = {
			if destNode.representedObject is Container {
				return destNode
			} else {
				if destNode.parent?.representedObject is Container {
					return destNode.parent!
				} else {
					return nil
				}
			}
		}()
		
		// Move the Feed
		let account = accountForNode(destNode)
		let sourceContainer = sourceNode.parent?.representedObject as? Container
		let destinationFolder = destParentNode?.representedObject as? Folder
		sourceContainer?.deleteFeed(feed)
		account?.addFeed(feed, to: destinationFolder)
		account?.structureDidChange()

	}
	
	// MARK: Actions
	
	@IBAction func showTools(_ sender: UIBarButtonItem) {
		
		let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
		
		// Settings Button
		let settingsTitle = NSLocalizedString("Settings", comment: "Settings")
		let setting  = UIAlertAction(title: settingsTitle, style: .default) { alertAction in
			
		}
		optionMenu.addAction(setting)
		
		// Import Button
		let importOPMLTitle = NSLocalizedString("Import OPML", comment: "Import OPML")
		let importOPML = UIAlertAction(title: importOPMLTitle, style: .default) { [unowned self] alertAction in
			let docPicker = UIDocumentPickerViewController(documentTypes: ["public.xml", "org.opml.opml"], in: .import)
			docPicker.delegate = self
			docPicker.modalPresentationStyle = .formSheet
			self.present(docPicker, animated: true)
		}
		optionMenu.addAction(importOPML)
		
		// Export Button
		let exportOPMLTitle = NSLocalizedString("Export OPML", comment: "Export OPML")
		let exportOPML = UIAlertAction(title: exportOPMLTitle, style: .default) { [unowned self] alertAction in
			
			let filename = "MySubscriptions.opml"
			let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
			let opmlString = OPMLExporter.OPMLString(with: AccountManager.shared.localAccount, title: filename)
			do {
				try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
			} catch {
				self.presentError(title: "OPML Export Error", message: error.localizedDescription)
			}
			
			let docPicker = UIDocumentPickerViewController(url: tempFile, in: .exportToService)
			docPicker.modalPresentationStyle = .formSheet
			self.present(docPicker, animated: true)
			
		}
		optionMenu.addAction(exportOPML)
		optionMenu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		
		if let popoverController = optionMenu.popoverPresentationController {
			popoverController.barButtonItem = sender
		}
		
		self.present(optionMenu, animated: true)
		
	}

	@IBAction func markAllAsRead(_ sender: Any) {
		
		let title = NSLocalizedString("Mark All Read", comment: "Mark All Read")
		let message = NSLocalizedString("Mark all articles in all accounts as read?", comment: "Mark all articles")
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
		alertController.addAction(cancelAction)
		
		let markTitle = NSLocalizedString("Mark All Read", comment: "Mark All Read")
		let markAction = UIAlertAction(title: markTitle, style: .default) { [weak self] (action) in
			
			let accounts = AccountManager.shared.accounts
			var articles = Set<Article>()
			accounts.forEach { account in
				articles.formUnion(account.fetchUnreadArticles())
			}
			
			guard let undoManager = self?.undoManager,
				let markReadCommand = MarkStatusCommand(initialArticles: Array(articles), markingRead: true, undoManager: undoManager) else {
					return
			}
			
			self?.runCommand(markReadCommand)
			
		}
		
		alertController.addAction(markAction)
		
		present(alertController, animated: true)
		
	}
	
	@IBAction func add(_ sender: UIBarButtonItem) {
		let feedViewController = UIStoryboard.add.instantiateInitialViewController()!
		feedViewController.modalPresentationStyle = .popover
		feedViewController.popoverPresentationController?.barButtonItem = sender
		self.present(feedViewController, animated: true)
	}
	
	@objc func toggleSectionHeader(_ sender: UITapGestureRecognizer) {
		
		guard let sectionIndex = sender.view?.tag,
			let sectionNode = treeController.rootNode.childAtIndex(sectionIndex)
				else {
					return
		}
		
		if expandedNodes.contains(sectionNode) {
			collapse(section: sectionIndex)
		} else {
			expand(section: sectionIndex)
		}
		
	}
	
	// MARK: API
	
	func configure(_ cell: MasterTableViewCell, _ node: Node) {
		
		cell.delegate = self
		cell.indent = node.parent?.representedObject is Folder
		cell.disclosureExpanded = expandedNodes.contains(node)
		cell.allowDisclosureSelection = node.canHaveChildNodes
		
		cell.name = nameFor(node)
		configureUnreadCount(cell, node)
		configureFavicon(cell, node)
		cell.shouldShowImage = node.representedObject is Feed
		
	}
	
	func configureUnreadCount(_ cell: MasterTableViewCell, _ node: Node) {
		cell.unreadCount = unreadCountFor(node)
	}
	
	func configureFavicon(_ cell: MasterTableViewCell, _ node: Node) {
		cell.faviconImage = imageFor(node)
	}

	func imageFor(_ node: Node) -> UIImage? {
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
	
	func delete(indexPath: IndexPath) {

		guard let undoManager = undoManager,
			let deleteNode = nodeFor(indexPath),
			let deleteCommand = DeleteCommand(nodesToDelete: [deleteNode], treeController: treeController, undoManager: undoManager)
				else {
					return
		}
		
		animatingChanges = true

		runCommand(deleteCommand)
		rebuildShadowTable()
		tableView.deleteRows(at: [indexPath], with: .automatic)
		
		animatingChanges = false
		
	}
	
	func rename(indexPath: IndexPath) {
		
		let name = (nodeFor(indexPath)?.representedObject as? DisplayNameProvider)?.nameForDisplay ?? ""
		let formatString = NSLocalizedString("Rename “%@”", comment: "Feed finder")
		let title = NSString.localizedStringWithFormat(formatString as NSString, name) as String
		
		let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
		
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIAlertAction(title: renameTitle, style: .default) { [weak self] action in
			
			guard let node = self?.nodeFor(indexPath),
				let name = alertController.textFields?[0].text,
				!name.isEmpty else {
					return
			}
			
			if let feed = node.representedObject as? Feed {
				feed.editedName = name
			} else if let folder = node.representedObject as? Folder {
				folder.name = name
			}
			
		}
		
		alertController.addAction(renameAction)
		
		alertController.addTextField() { textField in
			textField.placeholder = NSLocalizedString("Name", comment: "Name")
		}
		
		self.present(alertController, animated: true) {
			
		}
		
	}

	func nodeFor(_ indexPath: IndexPath) -> Node? {
		return shadowTable[indexPath.section][indexPath.row]
	}
	
	func indexPathFor(_ node: Node) -> IndexPath? {
		for i in 0..<shadowTable.count {
			if let row = shadowTable[i].firstIndex(of: node) {
				return IndexPath(row: row, section: i)
			}
		}
		return nil
	}
	
}

// MARK: OPML Document Picker

extension MasterViewController: UIDocumentPickerDelegate {
	
	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		
		for url in urls {
			do {
				try OPMLImporter.parseAndImport(fileURL: url, account: AccountManager.shared.localAccount)
			} catch {
				presentError(title: "OPML Import Error", message: error.localizedDescription)
			}
		}
		
	}
	
}

// MARK: MasterTableViewCellDelegate

extension MasterViewController: MasterTableViewCellDelegate {
	
	func disclosureSelected(_ sender: MasterTableViewCell, expanding: Bool) {
		if expanding {
			expand(sender)
		} else {
			collapse(sender)
		}
	}
	
}

// MARK: Private

private extension MasterViewController {
	
	@objc private func refreshAccounts(_ sender: Any) {
		AccountManager.shared.refreshAll()
	}
	
	func rebuildBackingStoresAndReloadDataIfNeeded() {
		if !animatingChanges && !BatchUpdate.shared.isPerforming {
			treeController.rebuild()
			rebuildShadowTable()
			tableView.reloadData()
		}
	}
	
	func configureCellsForRepresentedObject(_ representedObject: AnyObject) {
		
		applyToCellsForRepresentedObject(representedObject, configure)
	}

	func configureUnreadCountForCellsForRepresentedObject(_ representedObject: AnyObject) {
		applyToCellsForRepresentedObject(representedObject, configureUnreadCount)
	}
	
	func applyToCellsForRepresentedObject(_ representedObject: AnyObject, _ callback: (MasterTableViewCell, Node) -> Void) {
		applyToAvailableCells { (cell, node) in
			if node.representedObject === representedObject {
				callback(cell, node)
			}
		}
	}
	
	func applyToAvailableCells(_ callback: (MasterTableViewCell, Node) -> Void) {
		tableView.visibleCells.forEach { cell in
			guard let indexPath = tableView.indexPath(for: cell), let node = nodeFor(indexPath) else {
				return
			}
			callback(cell as! MasterTableViewCell, node)
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

	func rebuildShadowTable() {
		
		for i in 0..<treeController.rootNode.numberOfChildNodes {
			
			var result = [Node]()
			
			if let nodes = treeController.rootNode.childAtIndex(i)?.childNodes {
				for node in nodes {
					result.append(node)
					if expandedNodes.contains(node) {
						for child in node.childNodes {
							result.append(child)
						}
					}
				}
			}
			
			shadowTable[i] = result
			
		}

	}
	
	func expand(section: Int) {
		
		guard let expandNode = treeController.rootNode.childAtIndex(section) else {
			return
		}
		expandedNodes.append(expandNode)
		
		animatingChanges = true
		
		var indexPathsToInsert = [IndexPath]()
		var i = 0
		
		func addNode(_ node: Node) {
			indexPathsToInsert.append(IndexPath(row: i, section: section))
			shadowTable[section].insert(node, at: i)
			i = i + 1
		}
		
		for child in expandNode.childNodes {
			addNode(child)
			if expandedNodes.contains(child) {
				for gChild in child.childNodes {
					addNode(gChild)
				}
			}
		}
		
		tableView.beginUpdates()
		tableView.insertRows(at: indexPathsToInsert, with: .automatic)
		tableView.endUpdates()
		
		animatingChanges = false
		
	}
	
	func expand(_ cell: MasterTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell)  else {
			return
		}
		expand(indexPath)
	}
	
	func expand(_ indexPath: IndexPath) {
		
		let expandNode = shadowTable[indexPath.section][indexPath.row]
		expandedNodes.append(expandNode)
		
		animatingChanges = true
		
		var indexPathsToInsert = [IndexPath]()
		for i in 0..<expandNode.childNodes.count {
			if let child = expandNode.childAtIndex(i) {
				let nextIndex = indexPath.row + i + 1
				indexPathsToInsert.append(IndexPath(row: nextIndex, section: indexPath.section))
				shadowTable[indexPath.section].insert(child, at: nextIndex)
			}
		}
		
		tableView.beginUpdates()
		tableView.insertRows(at: indexPathsToInsert, with: .automatic)
		tableView.endUpdates()
		
		animatingChanges = false
		
	}
	
	func collapse(section: Int) {

		animatingChanges = true
		
		guard let collapseNode = treeController.rootNode.childAtIndex(section) else {
			return
		}
		if let removeNode = expandedNodes.firstIndex(of: collapseNode) {
			expandedNodes.remove(at: removeNode)
		}

		var indexPathsToRemove = [IndexPath]()
		for i in 0..<shadowTable[section].count {
			indexPathsToRemove.append(IndexPath(row: i, section: section))
		}
		shadowTable[section] = [Node]()
		
		tableView.beginUpdates()
		tableView.deleteRows(at: indexPathsToRemove, with: .automatic)
		tableView.endUpdates()
		
		animatingChanges = false
	}
	
	func collapse(_ cell: MasterTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell) else {
			return
		}
		collapse(indexPath)
	}
	
	func collapse(_ indexPath: IndexPath) {
		
		animatingChanges = true
		
		let collapseNode = shadowTable[indexPath.section][indexPath.row]
		if let removeNode = expandedNodes.firstIndex(of: collapseNode) {
			expandedNodes.remove(at: removeNode)
		}
		
		var indexPathsToRemove = [IndexPath]()
		
		for child in collapseNode.childNodes {
			if let index = shadowTable[indexPath.section].firstIndex(of: child) {
				indexPathsToRemove.append(IndexPath(row: index, section: indexPath.section))
			}
		}
		
		for child in collapseNode.childNodes {
			if let index = shadowTable[indexPath.section].firstIndex(of: child) {
				shadowTable[indexPath.section].remove(at: index)
			}
		}
		
		tableView.beginUpdates()
		tableView.deleteRows(at: indexPathsToRemove, with: .automatic)
		tableView.endUpdates()
		
		animatingChanges = false
		
	}
	
}
