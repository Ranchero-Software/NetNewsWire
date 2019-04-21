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
	
	let nmc = NavigationModelController()
	override var canBecomeFirstResponder: Bool {
		return true
	}

	override func viewDidLoad() {

		super.viewDidLoad()

		navigationItem.rightBarButtonItem = editButtonItem
		
		tableView.register(MasterTableViewSectionHeader.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		
		NotificationCenter.default.addObserver(self, selector: #selector(backingStoresDidRebuild(_:)), name: .BackingStoresDidRebuild, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .FeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddFeed(_:)), name: .UserDidAddFeed, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)

		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
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
	
	@objc dynamic func backingStoresDidRebuild(_ notification: Notification) {
		tableView.reloadData()
	}
	
	@objc dynamic func progressDidChange(_ notification: Notification) {
		if AccountManager.shared.combinedRefreshProgress.isComplete {
			refreshControl?.endRefreshing()
		} else {
			refreshControl?.beginRefreshing()
		}
	}

	@objc func unreadCountDidChange(_ note: Notification) {
		
		guard let representedObject = note.object else {
			return
		}
		
		if let account = representedObject as? Account {
			if let node = nmc.rootNode.childNodeRepresentingObject(account) {
				let sectionIndex = nmc.rootNode.indexOfChild(node)!
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
	
	@objc func userDidAddFeed(_ notification: Notification) {
		
		guard let feed = notification.userInfo?[UserInfoKey.feed],
			let node = nmc.rootNode.descendantNodeRepresentingObject(feed as AnyObject) else {
				return
		}
		
		if let indexPath = nmc.indexPathFor(node) {
			tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
			return
		}
	
		// It wasn't already visable, so expand its folder and try again
		guard let parent = node.parent, let indexPath = nmc.indexPathFor(parent) else {
			return
		}
		
		nmc.expand(indexPath) { [weak self] indexPaths in
			self?.tableView.beginUpdates()
			self?.tableView.insertRows(at: indexPaths, with: .automatic)
			self?.tableView.endUpdates()
		}

		if let indexPath = nmc.indexPathFor(node) {
			tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
		}

	}

	// MARK: Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return nmc.shadowTable.count
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return nmc.shadowTable[section].count
	}
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return CGFloat(integerLiteral: 44)
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		
		guard let nameProvider = nmc.rootNode.childAtIndex(section)?.representedObject as? DisplayNameProvider else {
			return nil
		}
		
		let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! MasterTableViewSectionHeader
		headerView.name = nameProvider.nameForDisplay
		
		guard let sectionNode = nmc.rootNode.childAtIndex(section) else {
			return headerView
		}
		
		if let account = sectionNode.representedObject as? Account {
			headerView.unreadCount = account.unreadCount
		} else {
			headerView.unreadCount = 0
		}
		
		headerView.tag = section
		headerView.disclosureExpanded = nmc.expandedNodes.contains(sectionNode)

		let tap = UITapGestureRecognizer(target: self, action:#selector(self.toggleSectionHeader(_:)))
		headerView.addGestureRecognizer(tap)

		return headerView
		
	}
	
	override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
		return CGFloat.leastNormalMagnitude
	}

	override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		return UIView(frame: CGRect.zero)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterTableViewCell
		
		guard let node = nmc.nodeFor(indexPath) else {
			return cell
		}
		
		configure(cell, node)
		return cell

	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		guard let node = nmc.nodeFor(indexPath), !(node.representedObject is PseudoFeed) else {
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
		
		guard let node = nmc.nodeFor(indexPath) else {
			assertionFailure()
			return
		}
		
		let timeline = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
		
		if let fetcher = node.representedObject as? ArticleFetcher {
			nmc.timelineFetcher = fetcher
		}
		
		if let nameProvider = node.representedObject as? DisplayNameProvider {
			timeline.title = nameProvider.nameForDisplay
		}
		
		timeline.nmc = nmc

		self.navigationController?.pushViewController(timeline, animated: true)

	}

	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		guard let node = nmc.nodeFor(indexPath) else {
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
		
		guard let draggedNode = nmc.nodeFor(sourceIndexPath), let destNode = nmc.nodeFor(destIndexPath), let parentNode = destNode.parent else {
			assertionFailure("This should never happen")
			return sourceIndexPath
		}
		
		// If this is a folder and isn't expanded or doesn't have any entries, let the users drop on it
		if destNode.representedObject is Folder && (destNode.numberOfChildNodes == 0 || !nmc.expandedNodes.contains(destNode)) {
			let movementAdjustment = sourceIndexPath > destIndexPath ? 1 : 0
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
				return nmc.indexPathFor(parentNode)!
			}
			
		} else {
			
			sortedNodes.remove(at: index)
			
			let movementAdjustment = sourceIndexPath < destIndexPath ? 1 : 0
			let adjustedIndex = index - movementAdjustment
			if adjustedIndex >= sortedNodes.count {
				let lastSortedIndexPath = nmc.indexPathFor(sortedNodes[sortedNodes.count - 1])!
				return IndexPath(row: lastSortedIndexPath.row + 1, section: lastSortedIndexPath.section)
			} else {
				return nmc.indexPathFor(sortedNodes[adjustedIndex])!
			}
			
		}
		
	}
	
	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {

		guard let sourceNode = nmc.nodeFor(sourceIndexPath), let feed = sourceNode.representedObject as? Feed else {
			return
		}

		// Based on the drop we have to determine a node to start looking for a parent container.
		let destNode: Node = {
			if destinationIndexPath.row == 0 {
				return nmc.rootNode.childAtIndex(destinationIndexPath.section)!
			} else {
				let movementAdjustment = sourceIndexPath > destinationIndexPath ? 1 : 0
				let adjustedDestIndexPath = IndexPath(row: destinationIndexPath.row - movementAdjustment, section: destinationIndexPath.section)
				return nmc.nodeFor(adjustedDestIndexPath)!
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
			let sectionNode = nmc.rootNode.childAtIndex(sectionIndex),
			let headerView = sender.view as? MasterTableViewSectionHeader
				else {
					return
		}
		
		if nmc.expandedNodes.contains(sectionNode) {
			headerView.disclosureExpanded = false
			nmc.collapse(section: sectionIndex) { [weak self] indexPaths in
				self?.tableView.beginUpdates()
				self?.tableView.deleteRows(at: indexPaths, with: .automatic)
				self?.tableView.endUpdates()
			}
		} else {
			headerView.disclosureExpanded = true
			nmc.expand(section: sectionIndex) { [weak self] indexPaths in
				self?.tableView.beginUpdates()
				self?.tableView.insertRows(at: indexPaths, with: .automatic)
				self?.tableView.endUpdates()
			}
		}
		
	}
	
	// MARK: API
	
	func configure(_ cell: MasterTableViewCell, _ node: Node) {
		
		cell.delegate = self
		if node.parent?.representedObject is Folder {
			cell.indentationLevel = 1
		} else {
			cell.indentationLevel = 0
		}
		cell.disclosureExpanded = nmc.expandedNodes.contains(node)
		cell.allowDisclosureSelection = node.canHaveChildNodes
		
		cell.name = nameFor(node)
		configureUnreadCount(cell, node)
		configureFavicon(cell, node)
		cell.shouldShowImage = node.representedObject is SmallIconProvider
		
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
			let deleteNode = nmc.nodeFor(indexPath),
			let deleteCommand = DeleteCommand(nodesToDelete: [deleteNode], treeController: nmc.treeController, undoManager: undoManager)
				else {
					return
		}
		
		nmc.animatingChanges = true

		runCommand(deleteCommand)
		nmc.rebuildShadowTable()
		tableView.deleteRows(at: [indexPath], with: .automatic)
		
		nmc.animatingChanges = false
		
	}
	
	func rename(indexPath: IndexPath) {
		
		let name = (nmc.nodeFor(indexPath)?.representedObject as? DisplayNameProvider)?.nameForDisplay ?? ""
		let formatString = NSLocalizedString("Rename “%@”", comment: "Feed finder")
		let title = NSString.localizedStringWithFormat(formatString as NSString, name) as String
		
		let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
		
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIAlertAction(title: renameTitle, style: .default) { [weak self] action in
			
			guard let node = self?.nmc.nodeFor(indexPath),
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
			guard let indexPath = tableView.indexPath(for: cell), let node = nmc.nodeFor(indexPath) else {
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

	func expand(_ cell: MasterTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell)  else {
			return
		}
		nmc.expand(indexPath) { [weak self] indexPaths in
			self?.tableView.beginUpdates()
			self?.tableView.insertRows(at: indexPaths, with: .automatic)
			self?.tableView.endUpdates()
		}
	}

	func collapse(_ cell: MasterTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell) else {
			return
		}
		nmc.collapse(indexPath) { [weak self] indexPaths in
			self?.tableView.beginUpdates()
			self?.tableView.deleteRows(at: indexPaths, with: .automatic)
			self?.tableView.endUpdates()
		}
	}

}
