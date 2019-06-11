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
import SwiftUI

class MasterFeedViewController: ProgressTableViewController, UndoableCommandRunner {

	@IBOutlet private weak var markAllAsReadButton: UIBarButtonItem!
	@IBOutlet private weak var addNewItemButton: UIBarButtonItem!
	
	var undoableCommands = [UndoableCommand]()
	
	let navState = NavigationStateController()
	override var canBecomeFirstResponder: Bool {
		return true
	}

	override func viewDidLoad() {

		super.viewDidLoad()

		navigationItem.rightBarButtonItem = editButtonItem
		
		tableView.register(MasterFeedTableViewSectionHeader.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .FeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddFeed(_:)), name: .UserDidAddFeed, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .AccountsDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(backingStoresDidRebuild(_:)), name: .BackingStoresDidRebuild, object: navState)
		NotificationCenter.default.addObserver(self, selector: #selector(masterSelectionDidChange(_:)), name: .MasterSelectionDidChange, object: navState)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)

		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
		updateUI()
		
	}

	override func viewWillAppear(_ animated: Bool) {
		clearsSelectionOnViewWillAppear = true
		navigationController?.title = NSLocalizedString("Feeds", comment: "Feeds")
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
	
	@objc func unreadCountDidChange(_ note: Notification) {
		
		updateUI()

		guard let representedObject = note.object else {
			return
		}
		
		if let account = representedObject as? Account {
			if let node = navState.rootNode.childNodeRepresentingObject(account) {
				let sectionIndex = navState.rootNode.indexOfChild(node)!
				if let headerView = tableView.headerView(forSection: sectionIndex) as? MasterFeedTableViewSectionHeader {
					headerView.unreadCount = account.unreadCount
				}
			}
			return
		}
		
		guard let node = navState.rootNode.descendantNodeRepresentingObject(representedObject as AnyObject),
			let indexPath = navState.indexPathFor(node) else {
				return
		}

		tableView.reloadRows(at: [indexPath], with: .automatic)

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
			let node = navState.rootNode.descendantNodeRepresentingObject(feed as AnyObject) else {
				return
		}
		
		if let indexPath = navState.indexPathFor(node) {
			tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
			return
		}
	
		// It wasn't already visable, so expand its folder and try again
		guard let parent = node.parent, let indexPath = navState.indexPathFor(parent) else {
			return
		}
		
		navState.expand(indexPath) { [weak self] indexPaths in
			self?.tableView.beginUpdates()
			self?.tableView.insertRows(at: indexPaths, with: .automatic)
			self?.tableView.endUpdates()
		}

		if let indexPath = navState.indexPathFor(node) {
			tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
		}

	}
	
	@objc func accountsDidChange(_ notification: Notification) {
		updateUI()
	}
	
	@objc func accountStateDidChange(_ notification: Notification) {
		updateUI()
	}
	
	@objc func masterSelectionDidChange(_ note: Notification) {
		if let indexPath = navState.currentMasterIndexPath {
			if tableView.indexPathForSelectedRow != indexPath {
				tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
			}
		}
	}
	
	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		tableView.reloadData()
	}
	
	// MARK: Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return navState.numberOfSections
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return navState.rowsInSection(section)
	}
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {

		guard let nameProvider = navState.rootNode.childAtIndex(section)?.representedObject as? DisplayNameProvider else {
			return 44
		}
		
		let headerView = MasterFeedTableViewSectionHeader()
		headerView.name = nameProvider.nameForDisplay

		let size = headerView.sizeThatFits(CGSize(width: tableView.bounds.width, height: 0.0))
		return size.height
		
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		
		guard let nameProvider = navState.rootNode.childAtIndex(section)?.representedObject as? DisplayNameProvider else {
			return nil
		}
		
		let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! MasterFeedTableViewSectionHeader
		headerView.name = nameProvider.nameForDisplay
		
		guard let sectionNode = navState.rootNode.childAtIndex(section) else {
			return headerView
		}
		
		if let account = sectionNode.representedObject as? Account {
			headerView.unreadCount = account.unreadCount
		} else {
			headerView.unreadCount = 0
		}
		
		headerView.tag = section
		headerView.disclosureExpanded = navState.isExpanded(sectionNode)

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
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterFeedTableViewCell
		
		guard let node = navState.nodeFor(indexPath) else {
			return cell
		}
		
		configure(cell, node)
		return cell

	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		guard let node = navState.nodeFor(indexPath), !(node.representedObject is PseudoFeed) else {
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
		
		let timeline = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
		timeline.navState = navState
		navState.currentMasterIndexPath = indexPath
		self.navigationController?.pushViewController(timeline, animated: true)

	}

	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		guard let node = navState.nodeFor(indexPath) else {
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
		
		guard let draggedNode = navState.nodeFor(sourceIndexPath), let destNode = navState.nodeFor(destIndexPath), let parentNode = destNode.parent else {
			assertionFailure("This should never happen")
			return sourceIndexPath
		}
		
		// If this is a folder and isn't expanded or doesn't have any entries, let the users drop on it
		if destNode.representedObject is Folder && (destNode.numberOfChildNodes == 0 || !navState.isExpanded(destNode)) {
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
				return navState.indexPathFor(parentNode)!
			}
			
		} else {
			
			sortedNodes.remove(at: index)
			
			let movementAdjustment = sourceIndexPath < destIndexPath ? 1 : 0
			let adjustedIndex = index - movementAdjustment
			if adjustedIndex >= sortedNodes.count {
				let lastSortedIndexPath = navState.indexPathFor(sortedNodes[sortedNodes.count - 1])!
				return IndexPath(row: lastSortedIndexPath.row + 1, section: lastSortedIndexPath.section)
			} else {
				return navState.indexPathFor(sortedNodes[adjustedIndex])!
			}
			
		}
		
	}
	
	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {

		guard let sourceNode = navState.nodeFor(sourceIndexPath), let feed = sourceNode.representedObject as? Feed else {
			return
		}

		// Based on the drop we have to determine a node to start looking for a parent container.
		let destNode: Node = {
			if destinationIndexPath.row == 0 {
				return navState.rootNode.childAtIndex(destinationIndexPath.section)!
			} else {
				let movementAdjustment = sourceIndexPath > destinationIndexPath ? 1 : 0
				let adjustedDestIndexPath = IndexPath(row: destinationIndexPath.row - movementAdjustment, section: destinationIndexPath.section)
				return navState.nodeFor(adjustedDestIndexPath)!
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
		guard let source = sourceNode.parent?.representedObject as? Container, let destination = destParentNode?.representedObject as? Container else {
			return
		}
		
		BatchUpdate.shared.start()
		source.account?.moveFeed(feed, from: source, to: destination) { result in
			switch result {
			case .success:
				BatchUpdate.shared.end()
			case .failure(let error):
				self.presentError(error)
			}
		}

	}
	
	// MARK: Actions
	
	@IBAction func settings(_ sender: UIBarButtonItem) {
		
		let settings = UIHostingController(rootView: SettingsView(viewModel: SettingsViewModel()))
		self.present(settings, animated: true)
		
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
			
			let accounts = AccountManager.shared.activeAccounts
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
		let addViewController = UIStoryboard.add.instantiateInitialViewController()!
		addViewController.modalPresentationStyle = .formSheet
		addViewController.preferredContentSize = AddContainerViewController.preferredContentSizeForFormSheetDisplay
		addViewController.popoverPresentationController?.barButtonItem = sender
		
		self.present(addViewController, animated: true)
	}
	
	@objc func toggleSectionHeader(_ sender: UITapGestureRecognizer) {
		
		guard let sectionIndex = sender.view?.tag,
			let sectionNode = navState.rootNode.childAtIndex(sectionIndex),
			let headerView = sender.view as? MasterFeedTableViewSectionHeader
				else {
					return
		}
		
		if navState.isExpanded(sectionNode) {
			headerView.disclosureExpanded = false
			navState.collapse(section: sectionIndex) { [weak self] indexPaths in
				self?.tableView.beginUpdates()
				self?.tableView.deleteRows(at: indexPaths, with: .automatic)
				self?.tableView.endUpdates()
			}
		} else {
			headerView.disclosureExpanded = true
			navState.expand(section: sectionIndex) { [weak self] indexPaths in
				self?.tableView.beginUpdates()
				self?.tableView.insertRows(at: indexPaths, with: .automatic)
				self?.tableView.endUpdates()
			}
		}
		
	}
	
	// MARK: API
	
	func configure(_ cell: MasterFeedTableViewCell, _ node: Node) {
		
		cell.delegate = self
		if node.parent?.representedObject is Folder {
			cell.indentationLevel = 1
		} else {
			cell.indentationLevel = 0
		}
		cell.disclosureExpanded = navState.isExpanded(node)
		cell.allowDisclosureSelection = node.canHaveChildNodes
		
		cell.name = nameFor(node)
		cell.unreadCount = unreadCountFor(node)
		configureFavicon(cell, node)
		cell.shouldShowImage = node.representedObject is SmallIconProvider
		
	}
	
	func configureFavicon(_ cell: MasterFeedTableViewCell, _ node: Node) {
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
			let deleteNode = navState.nodeFor(indexPath),
			let deleteCommand = DeleteCommand(nodesToDelete: [deleteNode], treeController: navState.treeController, undoManager: undoManager)
				else {
					return
		}

		var deleteIndexPaths = [indexPath]
		if navState.isExpanded(deleteNode) {
			for i in 0..<deleteNode.numberOfChildNodes {
				deleteIndexPaths.append(IndexPath(row: indexPath.row + 1 + i, section: indexPath.section))
			}
		}
		
		pushUndoableCommand(deleteCommand)

		navState.beginUpdates()
		deleteCommand.perform {
			self.navState.treeController.rebuild()
			self.navState.rebuildShadowTable()
			self.tableView.deleteRows(at: deleteIndexPaths, with: .automatic)
			self.navState.endUpdates()
		}
		
	}
	
	func rename(indexPath: IndexPath) {
		
		let name = (navState.nodeFor(indexPath)?.representedObject as? DisplayNameProvider)?.nameForDisplay ?? ""
		let formatString = NSLocalizedString("Rename “%@”", comment: "Feed finder")
		let title = NSString.localizedStringWithFormat(formatString as NSString, name) as String
		
		let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
		
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIAlertAction(title: renameTitle, style: .default) { [weak self] action in
			
			guard let node = self?.navState.nodeFor(indexPath),
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

// MARK: MasterTableViewCellDelegate

extension MasterFeedViewController: MasterFeedTableViewCellDelegate {
	
	func disclosureSelected(_ sender: MasterFeedTableViewCell, expanding: Bool) {
		if expanding {
			expand(sender)
		} else {
			collapse(sender)
		}
	}
	
}

// MARK: Private

private extension MasterFeedViewController {
	
	@objc private func refreshAccounts(_ sender: Any) {
		AccountManager.shared.refreshAll(errorHandler: ErrorHandler.present)
		refreshControl?.endRefreshing()
	}
	
	func updateUI() {
		markAllAsReadButton.isEnabled = navState.isAnyUnreadAvailable
		addNewItemButton.isEnabled = !AccountManager.shared.activeAccounts.isEmpty
	}

	func configureCellsForRepresentedObject(_ representedObject: AnyObject) {
		
		applyToCellsForRepresentedObject(representedObject, configure)
	}

	func applyToCellsForRepresentedObject(_ representedObject: AnyObject, _ callback: (MasterFeedTableViewCell, Node) -> Void) {
		applyToAvailableCells { (cell, node) in
			if node.representedObject === representedObject {
				callback(cell, node)
			}
		}
	}
	
	func applyToAvailableCells(_ callback: (MasterFeedTableViewCell, Node) -> Void) {
		tableView.visibleCells.forEach { cell in
			guard let indexPath = tableView.indexPath(for: cell), let node = navState.nodeFor(indexPath) else {
				return
			}
			callback(cell as! MasterFeedTableViewCell, node)
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

	func expand(_ cell: MasterFeedTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell)  else {
			return
		}
		navState.expand(indexPath) { [weak self] indexPaths in
			self?.tableView.beginUpdates()
			self?.tableView.insertRows(at: indexPaths, with: .automatic)
			self?.tableView.endUpdates()
		}
	}

	func collapse(_ cell: MasterFeedTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell) else {
			return
		}
		navState.collapse(indexPath) { [weak self] indexPaths in
			self?.tableView.beginUpdates()
			self?.tableView.deleteRows(at: indexPaths, with: .automatic)
			self?.tableView.endUpdates()
		}
	}

}
