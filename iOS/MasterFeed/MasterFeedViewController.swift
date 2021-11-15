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
import SafariServices

class MasterFeedViewController: UITableViewController, UndoableCommandRunner {

	@IBOutlet weak var filterButton: UIBarButtonItem!
	private var refreshProgressView: RefreshProgressView?
	@IBOutlet weak var addNewItemButton: UIBarButtonItem! {
		didSet {
			if #available(iOS 14, *) {
				addNewItemButton.primaryAction = nil
			} else {
				addNewItemButton.action = #selector(MasterFeedViewController.add(_:))
			}
		}
	}

	var undoableCommands = [UndoableCommand]()
	weak var coordinator: SceneCoordinator!
	
	private let keyboardManager = KeyboardManager(type: .sidebar)
	override var keyCommands: [UIKeyCommand]? {
		
		// If the first responder is the WKWebView (PreloadedWebView) we don't want to supply any keyboard
		// commands that the system is looking for by going up the responder chain. They will interfere with
		// the WKWebViews built in hardware keyboard shortcuts, specifically the up and down arrow keys.
		guard let current = UIResponder.currentFirstResponder, !(current is PreloadedWebView) else { return nil }
		
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
		
		// If you don't have an empty table header, UIKit tries to help out by putting one in for you
		// that makes a gap between the first section header and the navigation bar
		var frame = CGRect.zero
		frame.size.height = .leastNormalMagnitude
		tableView.tableHeaderView = UIView(frame: frame)
		
		tableView.register(MasterFeedTableViewSectionHeader.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		tableView.dragDelegate = self
		tableView.dropDelegate = self
		tableView.dragInteractionEnabled = true
		resetEstimatedRowHeight()
		tableView.separatorStyle = .none

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedSettingDidChange(_:)), name: .WebFeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(configureContextMenu(_:)), name: .ActiveExtensionPointsDidChange, object: nil)

		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
		configureToolbar()
		becomeFirstResponder()
	}

	override func viewWillAppear(_ animated: Bool) {
		updateUI()
		super.viewWillAppear(animated)
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
			IconImageCache.shared.emptyCache()
			reloadAllVisibleCells()
		}
	}

	// MARK: Notifications
	
	@objc func unreadCountDidChange(_ note: Notification) {
		updateUI()

		guard let unreadCountProvider = note.object as? UnreadCountProvider else {
			return
		}
		
		if let account = unreadCountProvider as? Account {
			if let node = coordinator.rootNode.childNodeRepresentingObject(account) {
				let sectionIndex = coordinator.rootNode.indexOfChild(node)!
				if let headerView = tableView.headerView(forSection: sectionIndex) as? MasterFeedTableViewSectionHeader {
					headerView.unreadCount = account.unreadCount
				}
			}
			return
		}
		
		var node: Node? = nil
		if let coordinator = unreadCountProvider as? SceneCoordinator, let feed = coordinator.timelineFeed {
			node = coordinator.rootNode.descendantNodeRepresentingObject(feed as AnyObject)
		} else {
			node = coordinator.rootNode.descendantNodeRepresentingObject(unreadCountProvider as AnyObject)
		}

		guard let unreadCountNode = node, let indexPath = coordinator.indexPathFor(unreadCountNode) else { return }
		if let cell = tableView.cellForRow(at: indexPath) as? MasterFeedTableViewCell {
			cell.unreadCount = unreadCountProvider.unreadCount
		}
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		applyToAvailableCells(configureIcon)
	}

	@objc func webFeedIconDidBecomeAvailable(_ note: Notification) {
		guard let webFeed = note.userInfo?[UserInfoKey.webFeed] as? WebFeed else {
			return
		}
		applyToCellsForRepresentedObject(webFeed, configureIcon(_:_:))
	}

	@objc func webFeedSettingDidChange(_ note: Notification) {
		guard let webFeed = note.object as? WebFeed, let key = note.userInfo?[WebFeed.WebFeedSettingUserInfoKey] as? String else {
			return
		}
		if key == WebFeed.WebFeedSettingKey.homePageURL || key == WebFeed.WebFeedSettingKey.faviconURL {
			configureCellsForRepresentedObject(webFeed)
		}
	}
	
	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		resetEstimatedRowHeight()
		tableView.reloadData()
	}
	
	@objc func willEnterForeground(_ note: Notification) {
		updateUI()
	}
	
	// MARK: Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		coordinator.numberOfSections()
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		coordinator.numberOfRows(in: section)
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterFeedTableViewCell
		configure(cell, indexPath)
		return cell
	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		if coordinator.nodeFor(indexPath)?.representedObject is PseudoFeed {
			return false
		} else {
			return true
		}
	}
	
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
		headerView.delegate = self
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
		
		if section == tableView.numberOfSections - 1 {
			headerView.isLastSection = true
		} else {
			headerView.isLastSection = false
		}

		headerView.gestureRecognizers?.removeAll()
		let tap = UITapGestureRecognizer(target: self, action:#selector(self.toggleSectionHeader(_:)))
		headerView.addGestureRecognizer(tap)
		
		// Without this the swipe gesture registers on the cell below
		let gestureRecognizer = UIPanGestureRecognizer(target: nil, action: nil)
		gestureRecognizer.delegate = self
		headerView.addGestureRecognizer(gestureRecognizer)

		headerView.interactions.removeAll()
		if section != 0 {
			headerView.addInteraction(UIContextMenuInteraction(delegate: self))
		}
		
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
		let deleteAction = UIContextualAction(style: .normal, title: deleteTitle) { [weak self] (action, view, completion) in
			self?.delete(indexPath: indexPath)
			completion(true)
		}
		deleteAction.backgroundColor = UIColor.systemRed
		actions.append(deleteAction)
		
		// Set up the rename action
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIContextualAction(style: .normal, title: renameTitle) { [weak self] (action, view, completion) in
			self?.rename(indexPath: indexPath)
			completion(true)
		}
		renameAction.backgroundColor = UIColor.systemOrange
		actions.append(renameAction)
		
		if let webFeed = coordinator.nodeFor(indexPath)?.representedObject as? WebFeed {
			let moreTitle = NSLocalizedString("More", comment: "More")
			let moreAction = UIContextualAction(style: .normal, title: moreTitle) { [weak self] (action, view, completion) in
				
				if let self = self {
				
					let alert = UIAlertController(title: webFeed.nameForDisplay, message: nil, preferredStyle: .actionSheet)
					if let popoverController = alert.popoverPresentationController {
						popoverController.sourceView = view
						popoverController.sourceRect = CGRect(x: view.frame.size.width/2, y: view.frame.size.height/2, width: 1, height: 1)
					}
					
					if let action = self.getInfoAlertAction(indexPath: indexPath, completion: completion) {
						alert.addAction(action)
					}
					
					if let action = self.homePageAlertAction(indexPath: indexPath, completion: completion) {
						alert.addAction(action)
					}
						
					if let action = self.copyFeedPageAlertAction(indexPath: indexPath, completion: completion) {
						alert.addAction(action)
					}

					if let action = self.copyHomePageAlertAction(indexPath: indexPath, completion: completion) {
						alert.addAction(action)
					}
					
					if let action = self.markAllAsReadAlertAction(indexPath: indexPath, completion: completion) {
						alert.addAction(action)
					}
					
					let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
					alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
						completion(true)
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
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed else {
			return nil
		}
		if feed is WebFeed {
			return makeWebFeedContextMenu(indexPath: indexPath, includeDeleteRename: true)
		} else if feed is Folder {
			return makeFolderContextMenu(indexPath: indexPath)
		} else if feed is PseudoFeed  {
			return makePseudoFeedContextMenu(indexPath: indexPath)
		} else {
			return nil
		}
	}
	
	override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
		guard let identifier = configuration.identifier as? MasterFeedRowIdentifier,
			  let cell = tableView.cellForRow(at: identifier.indexPath) else {
				  return nil
			  }

		return UITargetedPreview(view: cell, parameters: CroppingPreviewParameters(view: cell))
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		becomeFirstResponder()
		coordinator.selectFeed(indexPath: indexPath, animations: [.navigation, .select, .scroll])
	}

	override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {

		// Adjust the index path so that it will never be in the smart feeds area
		let destIndexPath: IndexPath = {
			if proposedDestinationIndexPath.section == 0 {
				return IndexPath(row: 0, section: 1)
			}
			return coordinator.cappedIndexPath(proposedDestinationIndexPath)
		}()
		
		guard let draggedNode = coordinator.nodeFor(sourceIndexPath) else {
			assertionFailure("This should never happen")
			return sourceIndexPath
		}
		
		// If there is no destination node, we are dragging onto an empty Account
		guard let destNode = coordinator.nodeFor(destIndexPath),
			  let destParentNode = destNode.parent else {
				  return proposedDestinationIndexPath
			  }
		
		// If this is a folder, let the users drop on it
		if destNode.representedObject is Folder {
			return proposedDestinationIndexPath
		}
		
		// If we are dragging around in the same container, just return the original source
		if destParentNode.childNodes.contains(draggedNode) {
			return sourceIndexPath
		}
		
		// Suggest to the user the best place to drop the feed
		// Revisit if the tree controller can ever be sorted in some other way.
		let nodes = destParentNode.childNodes + [draggedNode]
		var sortedNodes = nodes.sortedAlphabeticallyWithFoldersAtEnd()
		let index = sortedNodes.firstIndex(of: draggedNode)!

		sortedNodes.remove(at: index)

		if index == 0 {
			
			if destParentNode.representedObject is Account {
				return IndexPath(row: 0, section: destIndexPath.section)
			} else {
				if let candidateIndexPath = coordinator.indexPathFor(sortedNodes[index]) {
					let movementAdjustment = sourceIndexPath < destIndexPath ? 1 : 0
					return IndexPath(row: candidateIndexPath.row - movementAdjustment, section: candidateIndexPath.section)
				} else {
					return sourceIndexPath
				}
			}
			
		} else {
			
			if index >= sortedNodes.count {
				if let lastSortedIndexPath = coordinator.indexPathFor(sortedNodes[sortedNodes.count - 1]) {
					let movementAdjustment = sourceIndexPath > destIndexPath ? 1 : 0
					return IndexPath(row: lastSortedIndexPath.row + movementAdjustment, section: lastSortedIndexPath.section)
				} else {
					return sourceIndexPath
				}
			} else {
				let movementAdjustment = sourceIndexPath < destIndexPath ? 1 : 0
				return coordinator.indexPathFor(sortedNodes[index - movementAdjustment]) ?? sourceIndexPath
			}
			
		}
		
	}
	
	// MARK: Actions
	
	@IBAction func settings(_ sender: UIBarButtonItem) {
		coordinator.showSettings()
	}
	
	@IBAction func toggleFilter(_ sender: Any) {
		coordinator.toggleReadFeedsFilter()
	}
	
	@IBAction func add(_ sender: UIBarButtonItem) {
		
		if #available(iOS 14, *) {
			
		} else {
			let title = NSLocalizedString("Add Item", comment: "Add Item")
			let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
			
			let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
			let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
			
			let addWebFeedActionTitle = NSLocalizedString("Add Web Feed", comment: "Add Web Feed")
			let addWebFeedAction = UIAlertAction(title: addWebFeedActionTitle, style: .default) { _ in
				self.coordinator.showAddWebFeed()
			}
			
			let addRedditFeedActionTitle = NSLocalizedString("Add Reddit Feed", comment: "Add Reddit Feed")
			let addRedditFeedAction = UIAlertAction(title: addRedditFeedActionTitle, style: .default) { _ in
				self.coordinator.showAddRedditFeed()
			}
			
			let addTwitterFeedActionTitle = NSLocalizedString("Add Twitter Feed", comment: "Add Twitter Feed")
			let addTwitterFeedAction = UIAlertAction(title: addTwitterFeedActionTitle, style: .default) { _ in
				self.coordinator.showAddTwitterFeed()
			}
			
			let addWebFolderdActionTitle = NSLocalizedString("Add Folder", comment: "Add Folder")
			let addWebFolderAction = UIAlertAction(title: addWebFolderdActionTitle, style: .default) { _ in
				self.coordinator.showAddFolder()
			}
			
			alertController.addAction(addWebFeedAction)
			
			if AccountManager.shared.activeAccounts.contains(where: { $0.type == .onMyMac || $0.type == .cloudKit }) {
				if ExtensionPointManager.shared.isRedditEnabled {
					alertController.addAction(addRedditFeedAction)
				}
				if ExtensionPointManager.shared.isTwitterEnabled {
					alertController.addAction(addTwitterFeedAction)
				}
			}
			
			alertController.addAction(addWebFolderAction)
			alertController.addAction(cancelAction)
			
			alertController.popoverPresentationController?.barButtonItem = sender

			present(alertController, animated: true)
		}
		
		
	}
	
	@objc func toggleSectionHeader(_ sender: UITapGestureRecognizer) {
		guard let headerView = sender.view as? MasterFeedTableViewSectionHeader else {
			return
		}
		toggle(headerView)
	}
	
	@objc func refreshAccounts(_ sender: Any) {
		refreshControl?.endRefreshing()
		
		// This is a hack to make sure that an error dialog doesn't interfere with dismissing the refreshControl.
		// If the error dialog appears too closely to the call to endRefreshing, then the refreshControl never disappears.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			appDelegate.manualRefresh(errorHandler: ErrorHandler.present(self))
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
		if let indexPath = coordinator.currentFeedIndexPath, let node = coordinator.nodeFor(indexPath) {
			coordinator.expand(node)
		}
	}
	
	@objc func collapseSelectedRows(_ sender: Any?) {
		if let indexPath = coordinator.currentFeedIndexPath, let node = coordinator.nodeFor(indexPath) {
			coordinator.collapse(node)
		}
	}
	
	@objc func expandAll(_ sender: Any?) {
		coordinator.expandAllSectionsAndFolders()
	}
	
	@objc func collapseAllExceptForGroupItems(_ sender: Any?) {
		coordinator.collapseAllFolders()
	}

	@objc func markAllAsRead(_ sender: Any) {
		guard let indexPath = tableView.indexPathForSelectedRow, let contentView = tableView.cellForRow(at: indexPath)?.contentView else {
			return
		}

		let title = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")
		MarkAsReadAlertController.confirm(self, coordinator: coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
			self?.coordinator.markAllAsReadInTimeline()
		}
	}
	
	@objc func showFeedInspector(_ sender: Any?) {
		coordinator.showFeedInspector()
	}

	// MARK: API
	
	func restoreSelectionIfNecessary(adjustScroll: Bool) {
		if let indexPath = coordinator.masterFeedIndexPathForCurrentTimeline() {
			if adjustScroll {
				tableView.selectRowAndScrollIfNotVisible(at: indexPath, animations: [])
			} else {
				tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
			}
		}
	}

	func updateFeedSelection(animations: Animations) {
		if let indexPath = coordinator.currentFeedIndexPath {
			tableView.selectRowAndScrollIfNotVisible(at: indexPath, animations: animations)
		} else {
			if let indexPath = tableView.indexPathForSelectedRow {
				if animations.contains(.select) {
					tableView.deselectRow(at: indexPath, animated: true)
				} else {
					tableView.deselectRow(at: indexPath, animated: false)
				}
			}
		}
	}

	func reloadFeeds(initialLoad: Bool, changes: ShadowTableChanges, completion: (() -> Void)? = nil) {
		updateUI()

		guard !initialLoad else {
			tableView.reloadData()
			completion?()
			return
		}
		
		tableView.performBatchUpdates {
			if let deletes = changes.deletes, !deletes.isEmpty {
				tableView.deleteSections(IndexSet(deletes), with: .middle)
			}
			
			if let inserts = changes.inserts, !inserts.isEmpty {
				tableView.insertSections(IndexSet(inserts), with: .middle)
			}
			
			if let moves = changes.moves, !moves.isEmpty {
				for move in moves {
					tableView.moveSection(move.from, toSection: move.to)
				}
			}

			if let rowChanges = changes.rowChanges {
				for rowChange in rowChanges {
					if let deletes = rowChange.deleteIndexPaths, !deletes.isEmpty {
						tableView.deleteRows(at: deletes, with: .middle)
					}
					
					if let inserts = rowChange.insertIndexPaths, !inserts.isEmpty {
						tableView.insertRows(at: inserts, with: .middle)
					}
					
					if let moves = rowChange.moveIndexPaths, !moves.isEmpty {
						for move in moves {
							tableView.moveRow(at: move.0, to: move.1)
						}
					}
				}
			}
		}
		
		completion?()
	}
	
	func updateUI() {
		if coordinator.isReadFeedsFiltered {
			setFilterButtonToActive()
		} else {
			setFilterButtonToInactive()
		}
		refreshProgressView?.update()
		addNewItemButton?.isEnabled = !AccountManager.shared.activeAccounts.isEmpty

		configureContextMenu()
	}
	
	@objc
	func configureContextMenu(_: Any? = nil) {
		if #available(iOS 14.0, *) {
			
			/*
				Context Menu Order:
				1. Add Web Feed
				2. Add Reddit Feed
				3. Add Twitter Feed
				4. Add Folder
			*/
			
			var menuItems: [UIAction] = []
			
			let addWebFeedActionTitle = NSLocalizedString("Add Web Feed", comment: "Add Web Feed")
			let addWebFeedAction = UIAction(title: addWebFeedActionTitle, image: AppAssets.plus) { _ in
				self.coordinator.showAddWebFeed()
			}
			menuItems.append(addWebFeedAction)
			
			if AccountManager.shared.activeAccounts.contains(where: { $0.type == .onMyMac || $0.type == .cloudKit }) {
				if ExtensionPointManager.shared.isRedditEnabled {
					let addRedditFeedActionTitle = NSLocalizedString("Add Reddit Feed", comment: "Add Reddit Feed")
					let addRedditFeedAction = UIAction(title: addRedditFeedActionTitle, image: AppAssets.contextMenuReddit.tinted(color: .label)) { _ in
						self.coordinator.showAddRedditFeed()
					}
					menuItems.append(addRedditFeedAction)
				}
				if ExtensionPointManager.shared.isTwitterEnabled {
					let addTwitterFeedActionTitle = NSLocalizedString("Add Twitter Feed", comment: "Add Twitter Feed")
					let addTwitterFeedAction = UIAction(title: addTwitterFeedActionTitle, image: AppAssets.contextMenuTwitter.tinted(color: .label)) { _ in
						self.coordinator.showAddTwitterFeed()
					}
					menuItems.append(addTwitterFeedAction)
				}
			}
						
			let addWebFolderActionTitle = NSLocalizedString("Add Folder", comment: "Add Folder")
			let addWebFolderAction = UIAction(title: addWebFolderActionTitle, image: AppAssets.folderOutlinePlus) { _ in
				self.coordinator.showAddFolder()
			}
			
			menuItems.append(addWebFolderAction)
			
			let contextMenu = UIMenu(title: NSLocalizedString("Add Item", comment: "Add Item"), image: nil, identifier: nil, options: [], children: menuItems.reversed())
			
			self.addNewItemButton.menu = contextMenu
		}
	}
	
	func focus() {
		becomeFirstResponder()
	}

	func openInAppBrowser() {
		if let indexPath = coordinator.currentFeedIndexPath,
			let url = coordinator.homePageURLForFeed(indexPath) {
			let vc = SFSafariViewController(url: url)
			present(vc, animated: true)
		}
	}
	
}

// MARK: UIContextMenuInteractionDelegate

extension MasterFeedViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {

		guard let sectionIndex = interaction.view?.tag,
			let sectionNode = coordinator.rootNode.childAtIndex(sectionIndex),
			let account = sectionNode.representedObject as? Account
				else {
					return nil
		}
		
		return UIContextMenuConfiguration(identifier: sectionIndex as NSCopying, previewProvider: nil) { suggestedActions in

			var menuElements = [UIMenuElement]()
			menuElements.append(UIMenu(title: "", options: .displayInline, children: [self.getAccountInfoAction(account: account)]))

			if let markAllAction = self.markAllAsReadAction(account: account, contentView: interaction.view) {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: [markAllAction]))
			}

			menuElements.append(UIMenu(title: "", options: .displayInline, children: [self.deactivateAccountAction(account: account)]))
			
            return UIMenu(title: "", children: menuElements)
        }
    }
	
	func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
		
		guard let sectionIndex = configuration.identifier as? Int,
			let cell = tableView.headerView(forSection: sectionIndex) else {
				return nil
		}
		
		return UITargetedPreview(view: cell, parameters: CroppingPreviewParameters(view: cell))
	}
}

// MARK: MasterFeedTableViewSectionHeaderDelegate

extension MasterFeedViewController: MasterFeedTableViewSectionHeaderDelegate {
	
	func masterFeedTableViewSectionHeaderDisclosureDidToggle(_ sender: MasterFeedTableViewSectionHeader) {
		toggle(sender)
	}
	
}

// MARK: MasterTableViewCellDelegate

extension MasterFeedViewController: MasterFeedTableViewCellDelegate {
	
	func masterFeedTableViewCellDisclosureDidToggle(_ sender: MasterFeedTableViewCell, expanding: Bool) {
		if expanding {
			expand(sender)
		} else {
			collapse(sender)
		}
	}
	
}

// MARK: Private

private extension MasterFeedViewController {
	
	func configureToolbar() {
		guard let refreshProgressView = Bundle.main.loadNibNamed("RefreshProgressView", owner: self, options: nil)?[0] as? RefreshProgressView else {
			return
		}

		self.refreshProgressView = refreshProgressView
		let refreshProgressItemButton = UIBarButtonItem(customView: refreshProgressView)
		toolbarItems?.insert(refreshProgressItemButton, at: 2)
	}
	
	func setFilterButtonToActive() {
		filterButton?.image = AppAssets.filterActiveImage
		filterButton?.accLabelText = NSLocalizedString("Selected - Filter Read Feeds", comment: "Selected - Filter Read Feeds")
	}
	
	func setFilterButtonToInactive() {
		filterButton?.image = AppAssets.filterInactiveImage
		filterButton?.accLabelText = NSLocalizedString("Filter Read Feeds", comment: "Filter Read Feeds")
	}
	
	func resetEstimatedRowHeight() {
		let titleLabel = NonIntrinsicLabel()
		titleLabel.text = "But I must explain"
		
		let unreadCountView = MasterFeedUnreadCountView()
		unreadCountView.unreadCount = 10
		
		let layout = MasterFeedTableViewCellLayout(cellWidth: tableView.bounds.size.width, insets: tableView.safeAreaInsets, label: titleLabel, unreadCountView: unreadCountView, showingEditingControl: false, indent: false, shouldShowDisclosure: false)
		tableView.estimatedRowHeight = layout.height
	}
	
	func configure(_ cell: MasterFeedTableViewCell, _ indexPath: IndexPath) {
		guard let node = coordinator.nodeFor(indexPath) else { return }

		cell.delegate = self
		if node.representedObject is Folder {
			cell.indentationLevel = 0
		} else {
			cell.indentationLevel = 1
		}
		
		if let containerID = (node.representedObject as? Container)?.containerID {
			cell.setDisclosure(isExpanded: coordinator.isExpanded(containerID), animated: false)
			cell.isDisclosureAvailable = true
		} else {
			cell.isDisclosureAvailable = false
		}
		
		if let feed = node.representedObject as? Feed {
			cell.name = feed.nameForDisplay
			cell.unreadCount = feed.unreadCount
		}

		configureIcon(cell, indexPath)

		let rowsInSection = tableView.numberOfRows(inSection: indexPath.section)
		if indexPath.row == rowsInSection - 1 {
			cell.isSeparatorShown = false
		} else {
			cell.isSeparatorShown = true
		}
		
	}
	
	func configureIcon(_ cell: MasterFeedTableViewCell, _ indexPath: IndexPath) {
		guard let node = coordinator.nodeFor(indexPath), let feed = node.representedObject as? Feed, let feedID = feed.feedID else {
			return
		}
		cell.iconImage = IconImageCache.shared.imageFor(feedID)
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

	func applyToCellsForRepresentedObject(_ representedObject: AnyObject, _ completion: (MasterFeedTableViewCell, IndexPath) -> Void) {
		applyToAvailableCells { (cell, indexPath) in
			if let node = coordinator.nodeFor(indexPath),
			   let representedFeed = representedObject as? Feed,
			   let candidate = node.representedObject as? Feed,
			   representedFeed.feedID == candidate.feedID {
				completion(cell, indexPath)
			}
		}
	}
	
	func applyToAvailableCells(_ completion: (MasterFeedTableViewCell, IndexPath) -> Void) {
		tableView.visibleCells.forEach { cell in
			guard let indexPath = tableView.indexPath(for: cell) else {
				return
			}
			completion(cell as! MasterFeedTableViewCell, indexPath)
		}
	}

	private func reloadAllVisibleCells(completion: (() -> Void)? = nil) {
		guard let indexPaths = tableView.indexPathsForVisibleRows else { return }
		tableView.reloadRows(at: indexPaths, with: .none)
		restoreSelectionIfNecessary(adjustScroll: false)
	}
	
	private func accountForNode(_ node: Node) -> Account? {
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

	func toggle(_ headerView: MasterFeedTableViewSectionHeader) {
		guard let sectionNode = coordinator.rootNode.childAtIndex(headerView.tag) else {
			return
		}
		
		if coordinator.isExpanded(sectionNode) {
			headerView.disclosureExpanded = false
			coordinator.collapse(sectionNode)
		} else {
			headerView.disclosureExpanded = true
			coordinator.expand(sectionNode)
		}
	}

	func expand(_ cell: MasterFeedTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell), let node = coordinator.nodeFor(indexPath) else {
			return
		}
		coordinator.expand(node)
	}

	func collapse(_ cell: MasterFeedTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell), let node = coordinator.nodeFor(indexPath) else {
			return
		}
		coordinator.collapse(node)
	}

	func makeWebFeedContextMenu(indexPath: IndexPath, includeDeleteRename: Bool) -> UIContextMenuConfiguration {
		return UIContextMenuConfiguration(identifier: MasterFeedRowIdentifier(indexPath: indexPath), previewProvider: nil, actionProvider: { [ weak self] suggestedActions in
			
			guard let self = self else { return nil }
			
			var menuElements = [UIMenuElement]()
			
			if let inspectorAction = self.getInfoAction(indexPath: indexPath) {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: [inspectorAction]))
			}
			
			if let homePageAction = self.homePageAction(indexPath: indexPath) {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: [homePageAction]))
			}
			
			var pageActions = [UIAction]()
			if let copyFeedPageAction = self.copyFeedPageAction(indexPath: indexPath) {
				pageActions.append(copyFeedPageAction)
			}
			if let copyHomePageAction = self.copyHomePageAction(indexPath: indexPath) {
				pageActions.append(copyHomePageAction)
			}
			if !pageActions.isEmpty {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: pageActions))
			}

			if let markAllAction = self.markAllAsReadAction(indexPath: indexPath) {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: [markAllAction]))
			}
			
			if includeDeleteRename {
				menuElements.append(UIMenu(title: "",
										   options: .displayInline,
										   children: [
											self.renameAction(indexPath: indexPath),
											self.deleteAction(indexPath: indexPath)
										   ]))
			}
			
			return UIMenu(title: "", children: menuElements)
			
		})
		
	}
	
	func makeFolderContextMenu(indexPath: IndexPath) -> UIContextMenuConfiguration {
		return UIContextMenuConfiguration(identifier: MasterFeedRowIdentifier(indexPath: indexPath), previewProvider: nil, actionProvider: { [weak self] suggestedActions in

			guard let self = self else { return nil }
			
			var menuElements = [UIMenuElement]()

			if let markAllAction = self.markAllAsReadAction(indexPath: indexPath) {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: [markAllAction]))
			}
			
			menuElements.append(UIMenu(title: "",
									   options: .displayInline,
									   children: [
										self.renameAction(indexPath: indexPath),
										self.deleteAction(indexPath: indexPath)
									   ]))

			return UIMenu(title: "", children: menuElements)

		})
	}

	func makePseudoFeedContextMenu(indexPath: IndexPath) -> UIContextMenuConfiguration? {
		guard let markAllAction = self.markAllAsReadAction(indexPath: indexPath) else {
			return nil
		}

		return UIContextMenuConfiguration(identifier: MasterFeedRowIdentifier(indexPath: indexPath), previewProvider: nil, actionProvider: { suggestedActions in
			return UIMenu(title: "", children: [markAllAction])
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
	
	func homePageAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard coordinator.homePageURLForFeed(indexPath) != nil else {
			return nil
		}

		let title = NSLocalizedString("Open Home Page", comment: "Open Home Page")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.showBrowserForFeed(indexPath)
			completion(true)
		}
		return action
	}
	
	func copyFeedPageAction(indexPath: IndexPath) -> UIAction? {
		guard let webFeed = coordinator.nodeFor(indexPath)?.representedObject as? WebFeed,
			  let url = URL(string: webFeed.url) else {
				  return nil
			  }
		
		let title = NSLocalizedString("Copy Feed URL", comment: "Copy Feed URL")
		let action = UIAction(title: title, image: AppAssets.copyImage) { action in
			UIPasteboard.general.url = url
		}
		return action
	}
	
	func copyFeedPageAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let webFeed = coordinator.nodeFor(indexPath)?.representedObject as? WebFeed,
			  let url = URL(string: webFeed.url) else {
				  return nil
			  }

		let title = NSLocalizedString("Copy Feed URL", comment: "Copy Feed URL")
		let action = UIAlertAction(title: title, style: .default) { action in
			UIPasteboard.general.url = url
			completion(true)
		}
		return action
	}
	
	func copyHomePageAction(indexPath: IndexPath) -> UIAction? {
		guard let webFeed = coordinator.nodeFor(indexPath)?.representedObject as? WebFeed,
			  let homePageURL = webFeed.homePageURL,
			  let url = URL(string: homePageURL) else {
				  return nil
			  }
		
		let title = NSLocalizedString("Copy Home Page URL", comment: "Copy Home Page URL")
		let action = UIAction(title: title, image: AppAssets.copyImage) { action in
			UIPasteboard.general.url = url
		}
		return action
	}
	
	func copyHomePageAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let webFeed = coordinator.nodeFor(indexPath)?.representedObject as? WebFeed,
			  let homePageURL = webFeed.homePageURL,
			  let url = URL(string: homePageURL) else {
				  return nil
			  }

		let title = NSLocalizedString("Copy Home Page URL", comment: "Copy Home Page URL")
		let action = UIAlertAction(title: title, style: .default) { action in
			UIPasteboard.general.url = url
			completion(true)
		}
		return action
	}
	
	func markAllAsReadAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let webFeed = coordinator.nodeFor(indexPath)?.representedObject as? WebFeed,
			webFeed.unreadCount > 0,
			let articles = try? webFeed.fetchArticles(), let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else {
				return nil
		}
		
		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, webFeed.nameForDisplay) as String
		let cancel = {
			completion(true)
		}
		

		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView, cancelCompletion: cancel) { [weak self] in
				self?.coordinator.markAllAsRead(Array(articles))
				completion(true)
			}
		}
		return action
	}
	
	func deleteAction(indexPath: IndexPath) -> UIAction {
		let title = NSLocalizedString("Delete", comment: "Delete")
		
		let action = UIAction(title: title, image: AppAssets.trashImage, attributes: .destructive) { [weak self] action in
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
	
	func getInfoAction(indexPath: IndexPath) -> UIAction? {
		guard let webFeed = coordinator.nodeFor(indexPath)?.representedObject as? WebFeed else {
			return nil
		}
		
		let title = NSLocalizedString("Get Info", comment: "Get Info")
		let action = UIAction(title: title, image: AppAssets.infoImage) { [weak self] action in
			self?.coordinator.showFeedInspector(for: webFeed)
		}
		return action
	}

	func getAccountInfoAction(account: Account) -> UIAction {
		let title = NSLocalizedString("Get Info", comment: "Get Info")
		let action = UIAction(title: title, image: AppAssets.infoImage) { [weak self] action in
			self?.coordinator.showAccountInspector(for: account)
		}
		return action
	}

	func deactivateAccountAction(account: Account) -> UIAction {
		let title = NSLocalizedString("Deactivate", comment: "Deactivate")
		let action = UIAction(title: title, image: AppAssets.deactivateImage) { action in
			account.isActive = false
		}
		return action
	}

	func getInfoAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let webFeed = coordinator.nodeFor(indexPath)?.representedObject as? WebFeed else {
			return nil
		}

		let title = NSLocalizedString("Get Info", comment: "Get Info")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.showFeedInspector(for: webFeed)
			completion(true)
		}
		return action
	}

	func markAllAsReadAction(indexPath: IndexPath) -> UIAction? {
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed,
			  let contentView = self.tableView.cellForRow(at: indexPath)?.contentView,
			  feed.unreadCount > 0 else {
				  return nil
			  }
		
		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String
		let action = UIAction(title: title, image: AppAssets.markAllAsReadImage) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				if let articles = try? feed.fetchUnreadArticles() {
					self?.coordinator.markAllAsRead(Array(articles))
				}
			}
		}

		return action
	}

	func markAllAsReadAction(account: Account, contentView: UIView?) -> UIAction? {
		guard account.unreadCount > 0, let contentView = contentView else {
			return nil
		}

		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, account.nameForDisplay) as String
		let action = UIAction(title: title, image: AppAssets.markAllAsReadImage) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				// If you don't have this delay the screen flashes when it executes this code
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					if let articles = try? account.fetchArticles(.unread()) {
						self?.coordinator.markAllAsRead(Array(articles))
					}
				}
			}
		}

		return action
	}


	func rename(indexPath: IndexPath) {
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed else { return	}

		let formatString = NSLocalizedString("Rename “%@”", comment: "Rename feed")
		let title = NSString.localizedStringWithFormat(formatString as NSString, feed.nameForDisplay) as String
		
		let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
		
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIAlertAction(title: renameTitle, style: .default) { [weak self] action in
			
			guard let name = alertController.textFields?[0].text, !name.isEmpty else {
				return
			}
			
			if let webFeed = feed as? WebFeed {
				webFeed.rename(to: name) { result in
					switch result {
					case .success:
						break
					case .failure(let error):
						self?.presentError(error)
					}
				}
			} else if let folder = feed as? Folder {
				folder.rename(to: name) { result in
					switch result {
					case .success:
						break
					case .failure(let error):
						self?.presentError(error)
					}
				}
			}
			
		}
		
		alertController.addAction(renameAction)
		alertController.preferredAction = renameAction
		
		alertController.addTextField() { textField in
			textField.text = feed.nameForDisplay
			textField.placeholder = NSLocalizedString("Name", comment: "Name")
		}
		
		self.present(alertController, animated: true) {
			
		}
		
	}
	
	func delete(indexPath: IndexPath) {
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed else { return	}

		let title: String
		let message: String
		if feed is Folder {
			title = NSLocalizedString("Delete Folder", comment: "Delete folder")
			let localizedInformativeText = NSLocalizedString("Are you sure you want to delete the “%@” folder?", comment: "Folder delete text")
			message = NSString.localizedStringWithFormat(localizedInformativeText as NSString, feed.nameForDisplay) as String
		} else  {
			title = NSLocalizedString("Delete Feed", comment: "Delete feed")
			let localizedInformativeText = NSLocalizedString("Are you sure you want to delete the “%@” feed?", comment: "Feed delete text")
			message = NSString.localizedStringWithFormat(localizedInformativeText as NSString, feed.nameForDisplay) as String
		}
		
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
		
		let deleteTitle = NSLocalizedString("Delete", comment: "Delete")
		let deleteAction = UIAlertAction(title: deleteTitle, style: .destructive) { [weak self] action in
			self?.performDelete(indexPath: indexPath)
		}
		alertController.addAction(deleteAction)
		alertController.preferredAction = deleteAction
		
		self.present(alertController, animated: true)
	}
	
	func performDelete(indexPath: IndexPath) {
		guard let undoManager = undoManager,
			  let deleteNode = coordinator.nodeFor(indexPath),
			  let deleteCommand = DeleteCommand(nodesToDelete: [deleteNode], undoManager: undoManager, errorHandler: ErrorHandler.present(self)) else {
			return
		}

		if let folder = deleteNode.representedObject as? Folder {
			ActivityManager.cleanUp(folder)
		} else if let feed = deleteNode.representedObject as? WebFeed {
			ActivityManager.cleanUp(feed)
		}
		
		if indexPath == coordinator.currentFeedIndexPath {
			coordinator.selectFeed(indexPath: nil)
		}
		
		pushUndoableCommand(deleteCommand)
		deleteCommand.perform()
	}
	
}

extension MasterFeedViewController: UIGestureRecognizerDelegate {
	func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		guard let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer else {
			return false
		}
		let velocity = gestureRecognizer.velocity(in: self.view)
		return abs(velocity.x) > abs(velocity.y);
	}
}
