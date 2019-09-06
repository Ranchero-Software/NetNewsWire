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

class MasterFeedViewController: UITableViewController, UndoableCommandRunner {

	@IBOutlet private weak var markAllAsReadButton: UIBarButtonItem!
	@IBOutlet private weak var addNewItemButton: UIBarButtonItem!
	
	private lazy var dataSource = makeDataSource()
	var undoableCommands = [UndoableCommand]()
	weak var coordinator: SceneCoordinator!
	
	private let keyboardManager = KeyboardManager(type: .sidebar)
	override var keyCommands: [UIKeyCommand]? {
		return keyboardManager.keyCommands
	}
	
	override var canBecomeFirstResponder: Bool {
		return true
	}
	
	override func viewDidLoad() {

		super.viewDidLoad()

		if traitCollection.userInterfaceIdiom == .phone {
			navigationController?.navigationBar.prefersLargeTitles = true
		}
		
		navigationItem.rightBarButtonItem = editButtonItem
		
		tableView.register(MasterFeedTableViewSectionHeader.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		tableView.dataSource = dataSource
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .FeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddFeed(_:)), name: .UserDidAddFeed, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)

		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
		updateUI()
		applyChanges(animate: false)
		
	}

	override func viewWillAppear(_ animated: Bool) {
		navigationController?.title = NSLocalizedString("Feeds", comment: "Feeds")
		clearsSelectionOnViewWillAppear = coordinator.isRootSplitCollapsed
		super.viewWillAppear(animated)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		navigationController?.updateAccountRefreshProgressIndicator()
	}

	// MARK: Notifications
	
	@objc func unreadCountDidChange(_ note: Notification) {
		updateUI()

		guard let representedObject = note.object else {
			return
		}
		
		if let account = representedObject as? Account {
			if let node = coordinator.rootNode.childNodeRepresentingObject(account) {
				let sectionIndex = coordinator.rootNode.indexOfChild(node)!
				if let headerView = tableView.headerView(forSection: sectionIndex) as? MasterFeedTableViewSectionHeader {
					headerView.unreadCount = account.unreadCount
				}
			}
			return
		}
		
		var node: Node? = nil
		if let coordinator = representedObject as? SceneCoordinator, let fetcher = coordinator.timelineFetcher {
			node = coordinator.rootNode.descendantNodeRepresentingObject(fetcher as AnyObject)
		} else {
			node = coordinator.rootNode.descendantNodeRepresentingObject(representedObject as AnyObject)
		}

		if let node = node, coordinator.indexPathFor(node) != nil {
			reloadNode(node)
		}
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
		guard let feed = notification.userInfo?[UserInfoKey.feed] as? Feed else {
			return
		}
		discloseFeed(feed)
	}
	
	@objc func progressDidChange(_ note: Notification) {
		navigationController?.updateAccountRefreshProgressIndicator()
	}
	
	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		applyChanges(animate: false)
	}
	
	// MARK: Table View
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {

		guard let nameProvider = coordinator.rootNode.childAtIndex(section)?.representedObject as? DisplayNameProvider else {
			return 44
		}
		
		let headerView = MasterFeedTableViewSectionHeader()
		headerView.name = nameProvider.nameForDisplay

		let size = headerView.sizeThatFits(CGSize(width: tableView.bounds.width, height: 0.0))
		return size.height
		
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		
		guard let nameProvider = coordinator.rootNode.childAtIndex(section)?.representedObject as? DisplayNameProvider else {
			return nil
		}
		
		let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! MasterFeedTableViewSectionHeader
		headerView.name = nameProvider.nameForDisplay
		
		guard let sectionNode = coordinator.rootNode.childAtIndex(section) else {
			return headerView
		}
		
		if let account = sectionNode.representedObject as? Account {
			headerView.unreadCount = account.unreadCount
		} else {
			headerView.unreadCount = 0
		}
		
		headerView.tag = section
		headerView.disclosureExpanded = coordinator.isExpanded(sectionNode)

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

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		var actions = [UIContextualAction]()
		
		// Set up the delete action
		let deleteTitle = NSLocalizedString("Delete", comment: "Delete")
		let deleteAction = UIContextualAction(style: .normal, title: deleteTitle) { [weak self] (action, view, completionHandler) in
			self?.delete(indexPath: indexPath)
			completionHandler(true)
		}
		deleteAction.backgroundColor = UIColor.systemRed
		actions.append(deleteAction)
		
		// Set up the rename action
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIContextualAction(style: .normal, title: renameTitle) { [weak self] (action, view, completionHandler) in
			self?.rename(indexPath: indexPath)
			completionHandler(true)
		}
		renameAction.backgroundColor = UIColor.systemOrange
		actions.append(renameAction)
		
		if let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed {
			let moreTitle = NSLocalizedString("More", comment: "More")
			let moreAction = UIContextualAction(style: .normal, title: moreTitle) { [weak self] (action, view, completionHandler) in
				
				if let self = self {
				
					let alert = UIAlertController(title: feed.name, message: nil, preferredStyle: .actionSheet)
					if let popoverController = alert.popoverPresentationController {
						popoverController.sourceView = view
						popoverController.sourceRect = CGRect(x: view.frame.size.width/2, y: view.frame.size.height/2, width: 1, height: 1)
					}
					
					if let action = self.homePageAlertAction(indexPath: indexPath, completionHandler: completionHandler) {
						alert.addAction(action)
					}
						
					if let action = self.copyFeedPageAlertAction(indexPath: indexPath, completionHandler: completionHandler) {
						alert.addAction(action)
					}

					if let action = self.copyHomePageAlertAction(indexPath: indexPath, completionHandler: completionHandler) {
						alert.addAction(action)
					}
					
					let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
					alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
						completionHandler(true)
					})

					self.present(alert, animated: true)
					
				}
				
			}
			
			moreAction.backgroundColor = UIColor.systemGray
			actions.append(moreAction)
		}

		return UISwipeActionsConfiguration(actions: actions)
		
	}
	
	override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
		guard let node = coordinator.nodeFor(indexPath), !(node.representedObject is PseudoFeed) else {
			return nil
		}
		if node.representedObject is Feed {
			return makeFeedContextMenu(indexPath: indexPath, includeDeleteRename: true)
		} else {
			return makeFolderContextMenu(indexPath: indexPath)
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		becomeFirstResponder()
		coordinator.selectFeed(indexPath, automated: false)
	}

	override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

		// Adjust the index path so that it will never be in the smart feeds area
		let destIndexPath: IndexPath = {
			if proposedDestinationIndexPath.section == 0 {
				return IndexPath(row: 0, section: 1)
			}
			return coordinator.cappedIndexPath(proposedDestinationIndexPath)
		}()
		
		guard let draggedNode = coordinator.nodeFor(sourceIndexPath), let destNode = coordinator.nodeFor(destIndexPath), let parentNode = destNode.parent else {
			assertionFailure("This should never happen")
			return sourceIndexPath
		}
		
		// If this is a folder and isn't expanded or doesn't have any entries, let the users drop on it
		if destNode.representedObject is Folder && (destNode.numberOfChildNodes == 0 || !coordinator.isExpanded(destNode)) {
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
				return coordinator.indexPathFor(parentNode)!
			}
			
		} else {
			
			sortedNodes.remove(at: index)
			
			let movementAdjustment = sourceIndexPath < destIndexPath ? 1 : 0
			let adjustedIndex = index - movementAdjustment
			if adjustedIndex >= sortedNodes.count {
				let lastSortedIndexPath = coordinator.indexPathFor(sortedNodes[sortedNodes.count - 1])!
				return IndexPath(row: lastSortedIndexPath.row + 1, section: lastSortedIndexPath.section)
			} else {
				return coordinator.indexPathFor(sortedNodes[adjustedIndex])!
			}
			
		}
		
	}
	
	// MARK: Actions
	
	@IBAction func settings(_ sender: UIBarButtonItem) {
		coordinator.showSettings()
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
			self?.coordinator.markAllAsRead()
		}
		
		alertController.addAction(markAction)
		
		present(alertController, animated: true)
		
	}
	
	@IBAction func add(_ sender: UIBarButtonItem) {
		coordinator.showAdd(.feed)
	}
	
	@objc func toggleSectionHeader(_ sender: UITapGestureRecognizer) {
		
		guard let sectionIndex = sender.view?.tag,
			let sectionNode = coordinator.rootNode.childAtIndex(sectionIndex),
			let headerView = sender.view as? MasterFeedTableViewSectionHeader
				else {
					return
		}
		
		if coordinator.isExpanded(sectionNode) {
			headerView.disclosureExpanded = false
			coordinator.collapseSection(sectionIndex)
			self.applyChanges(animate: true)
		} else {
			headerView.disclosureExpanded = true
			coordinator.expandSection(sectionIndex)
			self.applyChanges(animate: true)
		}
		
	}
	
	@objc func refreshAccounts(_ sender: Any) {
		refreshControl?.endRefreshing()
		// This is a hack to make sure that an error dialog doesn't interfere with dismissing the refreshControl.
		// If the error dialog appears too closely to the call to endRefreshing, then the refreshControl never disappears.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			AccountManager.shared.refreshAll(errorHandler: ErrorHandler.present(self))
		}
	}
	
	// MARK: Keyboard shortcuts
	
	@objc func selectNextUp(_ sender: Any?) {
		coordinator.selectPrevFeed()
	}

	@objc func selectNextDown(_ sender: Any?) {
		coordinator.selectNextFeed()
	}

	@objc func navigateToTimeline(_ sender: Any?) {
		coordinator.navigateToTimeline()
	}

	@objc func openInBrowser(_ sender: Any?) {
		coordinator.showBrowserForCurrentFeed()
	}
	
	@objc override func delete(_ sender: Any?) {
		if let indexPath = coordinator.currentFeedIndexPath {
			delete(indexPath: indexPath)
		}
	}
	
	@objc func expandSelectedRows(_ sender: Any?) {
		if let indexPath = coordinator.currentFeedIndexPath {
			coordinator.expandFolder(indexPath)
			self.applyChanges(animate: true)
		}
	}
	
	@objc func collapseSelectedRows(_ sender: Any?) {
		if let indexPath = coordinator.currentFeedIndexPath {
			coordinator.collapseFolder(indexPath)
			self.applyChanges(animate: true)
		}
	}
	
	@objc func expandAll(_ sender: Any?) {
		coordinator.expandAllSectionsAndFolders()
		self.applyChanges(animate: true)
	}
	
	@objc func collapseAllExceptForGroupItems(_ sender: Any?) {
		coordinator.collapseAllFolders()
		self.applyChanges(animate: true)
	}
	
	// MARK: API
	
	func updateFeedSelection() {
		if let indexPath = coordinator.currentFeedIndexPath {
			if tableView.indexPathForSelectedRow != indexPath {
				tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
			}
		} else {
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		}
	}

	func reloadFeeds() {
		updateUI()

		// We have to reload all the visible cells because if we got here by doing a table cell move,
		// then the table itself is in a weird state.  This is because we do unusual things like allowing
		// drops on a "folder" that should cause the dropped cell to disappear.
		applyChanges(animate: true) { [weak self] in
			self?.reloadAllVisibleCells()
		}
	}
	
	func ensureSectionIsExpanded(_ sectionIndex: Int, completion: (() -> Void)? = nil) {
		guard let sectionNode = coordinator.rootNode.childAtIndex(sectionIndex) else {
				return
		}
		
		if !coordinator.isExpanded(sectionNode) {
			coordinator.expandSection(sectionIndex)
			self.applyChanges(animate: true) {
				completion?()
			}
		} else {
			completion?()
		}
	}
	
	func discloseFeed(_ feed: Feed, completion: (() -> Void)? = nil) {
		
		guard let node = coordinator.rootNode.descendantNodeRepresentingObject(feed as AnyObject) else {
			completion?()
			return
		}
		
		if let indexPath = coordinator.indexPathFor(node) {
			tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
			coordinator.selectFeed(indexPath)
			completion?()
			return
		}
	
		// It wasn't already visable, so expand its folder and try again
		guard let parent = node.parent, let indexPath = coordinator.indexPathFor(parent) else {
			completion?()
			return
		}
		
		coordinator.expandFolder(indexPath)
		reloadNode(parent)

		self.applyChanges(animate: true) { [weak self] in
			if let indexPath = self?.coordinator.indexPathFor(node) {
				self?.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
				self?.coordinator.selectFeed(indexPath)
				completion?()
			}
		}

	}

	func focus() {
		becomeFirstResponder()
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
	
	func updateUI() {
		markAllAsReadButton.isEnabled = coordinator.isAnyUnreadAvailable
		addNewItemButton.isEnabled = !AccountManager.shared.activeAccounts.isEmpty
	}
	
	func reloadNode(_ node: Node) {
		var snapshot = dataSource.snapshot()
		snapshot.reloadItems([node])
		dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
			self?.restoreSelectionIfNecessary()
		}
	}
	
	func applyChanges(animate: Bool, completion: (() -> Void)? = nil) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Node>()
		let sections = coordinator.allSections
		snapshot.appendSections(sections)

		for section in sections {
			snapshot.appendItems(coordinator.nodesFor(section: section), toSection: section)
		}
        
		dataSource.apply(snapshot, animatingDifferences: animate) { [weak self] in
			self?.restoreSelectionIfNecessary()
			completion?()
		}
	}

    func makeDataSource() -> UITableViewDiffableDataSource<Int, Node> {
		return MasterFeedDataSource(coordinator: coordinator, errorHandler: ErrorHandler.present(self), tableView: tableView, cellProvider: { [weak self] tableView, indexPath, node in
			let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterFeedTableViewCell
			self?.configure(cell, node)
			return cell
		})
    }
	
	func configure(_ cell: MasterFeedTableViewCell, _ node: Node) {
		
		cell.delegate = self
		if node.parent?.representedObject is Folder {
			cell.indentationLevel = 1
		} else {
			cell.indentationLevel = 0
		}
		cell.disclosureExpanded = coordinator.isExpanded(node)
		cell.allowDisclosureSelection = node.canHaveChildNodes
		
		cell.name = nameFor(node)
		cell.unreadCount = coordinator.unreadCountFor(node)
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
			guard let indexPath = tableView.indexPath(for: cell), let node = coordinator.nodeFor(indexPath) else {
				return
			}
			callback(cell as! MasterFeedTableViewCell, node)
		}
	}

	private func reloadAllVisibleCells() {
		let visibleNodes = tableView.indexPathsForVisibleRows!.compactMap { return coordinator.nodeFor($0) }
		reloadCells(visibleNodes)
	}
	
	private func reloadCells(_ nodes: [Node]) {
		var snapshot = dataSource.snapshot()
		snapshot.reloadItems(nodes)
		dataSource.apply(snapshot, animatingDifferences: false)
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
		coordinator.expandFolder(indexPath)
		self.applyChanges(animate: true)
	}

	func collapse(_ cell: MasterFeedTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell) else {
			return
		}
		coordinator.collapseFolder(indexPath)
		self.applyChanges(animate: true)
	}

	func restoreSelectionIfNecessary() {
		guard traitCollection.userInterfaceIdiom == .pad else {
			return
		}
		if let indexPath = coordinator.masterFeedIndexPathForCurrentTimeline(), indexPath != tableView.indexPathForSelectedRow {
			tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
		}
	}

	func makeFeedContextMenu(indexPath: IndexPath, includeDeleteRename: Bool) -> UIContextMenuConfiguration {
		return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { [ weak self] suggestedActions in
			
			guard let self = self else { return nil }
			
			var actions = [UIAction]()
			
			if let homePageAction = self.homePageAction(indexPath: indexPath) {
				actions.append(homePageAction)
			}
			
			if let copyFeedPageAction = self.copyFeedPageAction(indexPath: indexPath) {
				actions.append(copyFeedPageAction)
			}
			
			if let copyHomePageAction = self.copyHomePageAction(indexPath: indexPath) {
				actions.append(copyHomePageAction)
			}
			
			if includeDeleteRename {
				actions.append(self.deleteAction(indexPath: indexPath))
				actions.append(self.renameAction(indexPath: indexPath))
			}
			
			return UIMenu(title: "", children: actions)
			
		})
		
	}
	
	func makeFolderContextMenu(indexPath: IndexPath) -> UIContextMenuConfiguration {
		return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { [weak self] suggestedActions in

			guard let self = self else { return nil }
			
			var actions = [UIAction]()
			actions.append(self.deleteAction(indexPath: indexPath))
			actions.append(self.renameAction(indexPath: indexPath))
			
			return UIMenu(title: "", children: actions)

		})
	}

	func homePageAction(indexPath: IndexPath) -> UIAction? {
		guard coordinator.homePageURLForFeed(indexPath) != nil else {
			return nil
		}
		
		let title = NSLocalizedString("Open Home Page", comment: "Open Home Page")
		let action = UIAction(title: title, image: AppAssets.safariImage) { [weak self] action in
			self?.coordinator.showBrowserForFeed(indexPath)
		}
		return action
	}
	
	func homePageAlertAction(indexPath: IndexPath, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard coordinator.homePageURLForFeed(indexPath) != nil else {
			return nil
		}

		let title = NSLocalizedString("Open Home Page", comment: "Open Home Page")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.showBrowserForFeed(indexPath)
			completionHandler(true)
		}
		return action
	}
	
	func copyFeedPageAction(indexPath: IndexPath) -> UIAction? {
		guard let node = coordinator.nodeFor(indexPath),
			let feed = node.representedObject as? Feed,
			let url = URL(string: feed.url) else {
				return nil
		}
		
		let title = NSLocalizedString("Copy Feed URL", comment: "Copy Feed URL")
		let action = UIAction(title: title, image: AppAssets.copyImage) { action in
			UIPasteboard.general.url = url
		}
		return action
	}
	
	func copyFeedPageAlertAction(indexPath: IndexPath, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let node = coordinator.nodeFor(indexPath),
			let feed = node.representedObject as? Feed,
			let url = URL(string: feed.url) else {
				return nil
		}
		
		let title = NSLocalizedString("Copy Feed URL", comment: "Copy Feed URL")
		let action = UIAlertAction(title: title, style: .default) { action in
			UIPasteboard.general.url = url
			completionHandler(true)
		}
		return action
	}
	
	func copyHomePageAction(indexPath: IndexPath) -> UIAction? {
		guard let node = coordinator.nodeFor(indexPath),
			let feed = node.representedObject as? Feed,
			let homePageURL = feed.homePageURL,
			let url = URL(string: homePageURL) else {
				return nil
		}
		
		let title = NSLocalizedString("Copy Home Page URL", comment: "Copy Home Page URL")
		let action = UIAction(title: title, image: AppAssets.copyImage) { action in
			UIPasteboard.general.url = url
		}
		return action
	}
	
	func copyHomePageAlertAction(indexPath: IndexPath, completionHandler: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let node = coordinator.nodeFor(indexPath),
			let feed = node.representedObject as? Feed,
			let homePageURL = feed.homePageURL,
			let url = URL(string: homePageURL) else {
				return nil
		}
		
		let title = NSLocalizedString("Copy Home Page URL", comment: "Copy Home Page URL")
		let action = UIAlertAction(title: title, style: .default) { action in
			UIPasteboard.general.url = url
			completionHandler(true)
		}
		return action
	}
	
	func deleteAction(indexPath: IndexPath) -> UIAction {
		let title = NSLocalizedString("Delete", comment: "Delete")
		let action = UIAction(title: title, image: AppAssets.trashImage) { [weak self] action in
			self?.delete(indexPath: indexPath)
		}
		return action
	}
	
	func renameAction(indexPath: IndexPath) -> UIAction {
		let title = NSLocalizedString("Rename", comment: "Rename")
		let action = UIAction(title: title, image: AppAssets.editImage) { [weak self] action in
			self?.rename(indexPath: indexPath)
		}
		return action
	}
	
	func rename(indexPath: IndexPath) {
		
		let name = (coordinator.nodeFor(indexPath)?.representedObject as? DisplayNameProvider)?.nameForDisplay ?? ""
		let formatString = NSLocalizedString("Rename “%@”", comment: "Feed finder")
		let title = NSString.localizedStringWithFormat(formatString as NSString, name) as String
		
		let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
		
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIAlertAction(title: renameTitle, style: .default) { [weak self] action in
			
			guard let node = self?.coordinator.nodeFor(indexPath),
				let name = alertController.textFields?[0].text,
				!name.isEmpty else {
					return
			}
			
			if let feed = node.representedObject as? Feed {
				feed.rename(to: name) { result in
					switch result {
					case .success:
						self?.reloadNode(node)
					case .failure(let error):
						self?.presentError(error)
					}
				}
			} else if let folder = node.representedObject as? Folder {
				folder.rename(to: name) { result in
					switch result {
					case .success:
						self?.reloadNode(node)
					case .failure(let error):
						self?.presentError(error)
					}
				}
			}
			
		}
		
		alertController.addAction(renameAction)
		
		alertController.addTextField() { textField in
			textField.placeholder = NSLocalizedString("Name", comment: "Name")
		}
		
		self.present(alertController, animated: true) {
			
		}
		
	}
	
	func delete(indexPath: IndexPath) {
		guard let undoManager = undoManager,
			let deleteNode = coordinator.nodeFor(indexPath),
			let deleteCommand = DeleteCommand(nodesToDelete: [deleteNode], undoManager: undoManager, errorHandler: ErrorHandler.present(self))
				else {
					return
		}

		if let folder = deleteNode.representedObject as? Folder {
			ActivityManager.cleanUp(folder)
		} else if let feed = deleteNode.representedObject as? Feed {
			ActivityManager.cleanUp(feed)
		}
		
		pushUndoableCommand(deleteCommand)
		deleteCommand.perform()
	}
	
}
