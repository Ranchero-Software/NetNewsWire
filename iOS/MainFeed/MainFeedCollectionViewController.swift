//
//  MainFeedCollectionViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 23/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import os
import SafariServices
import UniformTypeIdentifiers
import WebKit
import RSCore
import RSTree
import RSWeb
import Account
import Articles

private let reuseIdentifier = "FeedCell"
private let folderIdentifier = "Folder"
private let containerReuseIdentifier = "Container"

final class MainFeedCollectionViewController: UICollectionViewController, UndoableCommandRunner {
	@IBOutlet var filterButton: UIBarButtonItem!
	@IBOutlet var addNewItemButton: UIBarButtonItem! {
		didSet {
			if #available(iOS 14, *) {
				addNewItemButton.primaryAction = nil
			} else {
				addNewItemButton.action = #selector(MainFeedCollectionViewController.add(_:))
			}
		}
	}

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

	var undoableCommands = [UndoableCommand]()
	weak var coordinator: SceneCoordinator!

	/// On iPhone, this property is used to prevent the user from selecting a new feed while the current feed is being deselected.
	/// While `isAnimating` is `true`, `shouldSelectItemAt()` will not allow new selection.
	/// The value is set to `true` in `viewWillAppear(_:)` if a feed is selected, and reset to `false` in
	/// `viewDidAppear(_:)` after a delay to allow the deselection animation to complete.
	private var isAnimating: Bool = false

	override func viewDidLoad() {
		super.viewDidLoad()
		registerForNotifications()
		configureCollectionView()
		collectionView.dragDelegate = self
		collectionView.dropDelegate = self
		becomeFirstResponder()
    }

	override func viewWillAppear(_ animated: Bool) {
		navigationController?.isToolbarHidden = false
		updateUI()
		super.viewWillAppear(animated)

		collectionView.refreshControl = UIRefreshControl()
		collectionView.refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)

		if traitCollection.userInterfaceIdiom == .phone {
			self.navigationController?.navigationBar.prefersLargeTitles = false

			/// On iPhone, we want to deselect the feed when the user navigates
			/// back to the feeds view. To prevent the user from selecting a new feed while
			/// the current feed is being deselected, set `isAnimating` to true.
			///
			/// `shouldSelectItemAt()` will not allow selection when `isAnimating`
			/// is `true.`
			if let _ = collectionView.indexPathsForSelectedItems {
				isAnimating = true
			}
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		/// On iPhone, once the deselection animation has completed, set `isAnimating`
		/// to false and this will allow selection.
		if traitCollection.userInterfaceIdiom == .phone {
			if let _ = collectionView.indexPathsForSelectedItems {
				coordinator.selectFeed(indexPath: nil, animations: [.select])
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
					self.isAnimating = false
				})
			}
		}
	}

	func registerForNotifications() {
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		// TODO: fix this temporary hack, which will probably require refactoring image handling.
		// We want to know when to possibly reconfigure our cells with a new image, and we don’t
		// always know when an image is available — but watching the .htmlMetadataAvailable Notification
		// lets us know that it’s time to request an image.
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .htmlMetadataAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .feedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .feedSettingDidChange, object: nil)

		registerForTraitChanges([UITraitPreferredContentSizeCategory.self], target: self, action: #selector(preferredContentSizeCategoryDidChange))
	}

	// MARK: - Collection View Configuration
	func configureCollectionView() {
		var config = UICollectionLayoutListConfiguration(appearance: traitCollection.userInterfaceIdiom == .pad ? .sidebar : .insetGrouped)
		config.separatorConfiguration.color = .tertiarySystemFill
		config.headerMode = .supplementary

		config.trailingSwipeActionsConfigurationProvider = { [unowned self] indexPath in
			if indexPath.section == 0 { return UISwipeActionsConfiguration(actions: []) }
			var actions = [UIContextualAction]()

			// Set up the delete action
			let deleteTitle = NSLocalizedString("Delete", comment: "Delete")
			let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] (action, view, completion) in
				self?.delete(indexPath: indexPath)
				completion(true)
			}
			deleteAction.image = UIImage(systemName: "trash")
			deleteAction.accessibilityLabel = deleteTitle
			deleteAction.backgroundColor = UIColor.systemRed
			actions.append(deleteAction)

			// Set up the rename action
			let renameTitle = NSLocalizedString("Rename", comment: "Rename")
			let renameAction = UIContextualAction(style: .normal, title: nil) { [weak self] (action, view, completion) in
				self?.rename(indexPath: indexPath)
				completion(true)
			}
			renameAction.backgroundColor = UIColor.systemOrange
			renameAction.image = UIImage(systemName: "pencil")
			renameAction.accessibilityLabel = renameTitle
			actions.append(renameAction)

			if let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed {
				let moreTitle = NSLocalizedString("More", comment: "More")
				let moreAction = UIContextualAction(style: .normal, title: nil) { [weak self] (action, view, completion) in

					if let self = self {

						let alert = UIAlertController(title: feed.nameForDisplay, message: nil, preferredStyle: .actionSheet)
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
				moreAction.image = UIImage(systemName: "ellipsis")
				moreAction.accessibilityLabel = moreTitle
				actions.append(moreAction)
			}

			let config = UISwipeActionsConfiguration(actions: actions)
			config.performsFirstActionWithFullSwipe = false

			return config
		}

		let layout = UICollectionViewCompositionalLayout.list(using: config)
		collectionView.setCollectionViewLayout(layout, animated: false)
		collectionView.refreshControl = UIRefreshControl()
		collectionView.refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)

		if config.appearance == .sidebar {
			// This defrosts the glass.
			collectionView.backgroundColor = .clear
		}
	}

	@IBAction func settings(_ sender: UIBarButtonItem) {
		coordinator.showSettings()
	}

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
		return coordinator.numberOfSections()
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
		return coordinator.numberOfRows(in: section)
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let node = coordinator.nodeFor(indexPath), let _ = node.representedObject as? Folder else {
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? MainFeedCollectionViewCell
			configure(cell!, indexPath: indexPath)
			return cell!
		}

		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: folderIdentifier, for: indexPath) as! MainFeedCollectionViewFolderCell
		configure(cell, indexPath: indexPath)
		cell.delegate = self
		return cell

    }

	override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		guard kind == UICollectionView.elementKindSectionHeader else {
				return UICollectionReusableView()
			}

		let headerView = collectionView.dequeueReusableSupplementaryView(
			ofKind: kind,
			withReuseIdentifier: containerReuseIdentifier,
			for: indexPath
		) as! MainFeedCollectionHeaderReusableView

		guard let nameProvider = coordinator.rootNode.childAtIndex(indexPath.section)?.representedObject as? DisplayNameProvider else {
			return UICollectionReusableView()
		}

		headerView.delegate = self
		headerView.headerTitle.text = nameProvider.nameForDisplay

		guard let sectionNode = coordinator.rootNode.childAtIndex(indexPath.section) else {
			return headerView
		}

		if let account = sectionNode.representedObject as? Account {
			headerView.unreadCount = account.unreadCount
		} else {
			headerView.unreadCount = 0
		}

		headerView.tag = indexPath.section
		headerView.disclosureExpanded = coordinator.isExpanded(sectionNode)

		if indexPath.section != 0 {
			headerView.addInteraction(UIContextMenuInteraction(delegate: self))
		}

		return headerView
	}

	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		becomeFirstResponder()
		coordinator.selectFeed(indexPath: indexPath, animations: [.navigation, .select, .scroll])
	}

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
		if traitCollection.userInterfaceIdiom == .pad { return true }
		return !isAnimating
    }

	override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {

    }

	override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
		guard let sidebarItem = coordinator.nodeFor(indexPath)?.representedObject as? SidebarItem else {
			return nil
		}
		if sidebarItem is Feed {
			return makeFeedContextMenu(indexPath: indexPath, includeDeleteRename: true)
		} else if sidebarItem is Folder {
			return makeFolderContextMenu(indexPath: indexPath)
		} else if sidebarItem is PseudoFeed  {
			return makePseudoFeedContextMenu(indexPath: indexPath)
		} else {
			return nil
		}
	}

	// MARK: - Key Commands

	// MARK: - Keyboard shortcuts

	@objc func collapseAllExceptForGroupItems(_ sender: Any?) {
		coordinator.collapseAllFolders()
	}

	@objc func collapseSelectedRows(_ sender: Any?) {
		if let indexPath = coordinator.currentFeedIndexPath, let node = coordinator.nodeFor(indexPath) {
			coordinator.collapse(node)
			if let folder = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewFolderCell {
				folder.disclosureExpanded = false
			}
		}
	}

	@objc override func delete(_ sender: Any?) {
		if let indexPath = coordinator.currentFeedIndexPath {
			delete(indexPath: indexPath)
		}
	}

	@objc func expandAll(_ sender: Any?) {
		coordinator.expandAllSectionsAndFolders()
	}

	@objc func expandSelectedRows(_ sender: Any?) {
		if let indexPath = coordinator.currentFeedIndexPath, let node = coordinator.nodeFor(indexPath) {
			coordinator.expand(node)
			if let folder = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewFolderCell {
				folder.disclosureExpanded = true
			}
		}
	}

	@objc func markAllAsRead(_ sender: Any) {
		guard let indexPath = collectionView.indexPathsForSelectedItems?.first, let contentView = collectionView.cellForItem(at: indexPath)?.contentView else {
			return
		}

		let title = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")
		MarkAsReadAlertController.confirm(self, coordinator: coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
			self?.coordinator.markAllAsReadInTimeline()
		}
	}

	@objc func navigateToTimeline(_ sender: Any?) {
		coordinator.navigateToTimeline()
	}

	@objc func openInBrowser(_ sender: Any?) {
		coordinator.showBrowserForCurrentFeed()
	}

	@objc func selectNextDown(_ sender: Any?) {
		coordinator.selectNextFeed()
	}

	@objc func selectNextUp(_ sender: Any?) {
		coordinator.selectPrevFeed()
	}

	@objc func showFeedInspector(_ sender: Any?) {
		coordinator.showFeedInspector()
	}

	// MARK: - API

	func focus() {
		becomeFirstResponder()
	}

	func updateUI() {
		if coordinator.isReadFeedsFiltered {
			setFilterButtonToActive()
		} else {
			setFilterButtonToInactive()
		}
		addNewItemButton?.isEnabled = !AccountManager.shared.activeAccounts.isEmpty

		configureContextMenu()
	}

	func updateFeedSelection(animations: Animations) {
		if let indexPath = coordinator.currentFeedIndexPath {
			collectionView.selectItemAndScrollIfNotVisible(at: indexPath, animations: animations)
		} else {
			if let indexPath = collectionView.indexPathsForSelectedItems?.first {
				if animations.contains(.select) {
					collectionView.deselectItem(at: indexPath, animated: true)
				} else {
					collectionView.deselectItem(at: indexPath, animated: false)
				}
			}
		}
	}

	func openInAppBrowser() {
		if let indexPath = coordinator.currentFeedIndexPath,
			let url = coordinator.homePageURLForFeed(indexPath) {
			let vc = SFSafariViewController(url: url)
			vc.modalPresentationStyle = .overFullScreen
			present(vc, animated: true)
		}
	}

	func reloadFeeds(initialLoad: Bool, changes: ShadowTableChanges, completion: (() -> Void)? = nil) {
		updateUI()

		guard !initialLoad else {
			collectionView.reloadData()
			completion?()
			return
		}

		collectionView.performBatchUpdates {
			if let deletes = changes.deletes, !deletes.isEmpty {
				collectionView.deleteSections(IndexSet(deletes))
			}

			if let inserts = changes.inserts, !inserts.isEmpty {
				collectionView.insertSections(IndexSet(inserts))
			}

			if let moves = changes.moves, !moves.isEmpty {
				for move in moves {
					collectionView.moveSection(move.from, toSection: move.to)
				}
			}

			if let rowChanges = changes.rowChanges {
				for rowChange in rowChanges {
					if let deletes = rowChange.deleteIndexPaths, !deletes.isEmpty {
						collectionView.deleteItems(at: deletes)
					}

					if let inserts = rowChange.insertIndexPaths, !inserts.isEmpty {
						collectionView.insertItems(at: inserts)
					}

					if let moves = rowChange.moveIndexPaths, !moves.isEmpty {
						for move in moves {
							collectionView.moveItem(at: move.0, to: move.1)
						}
					}
				}
			}
		}

		if let rowChanges = changes.rowChanges {
			for rowChange in rowChanges {
				if let reloads = rowChange.reloadIndexPaths, !reloads.isEmpty {
					collectionView.reloadItems(at: reloads)
				}
			}
		}

		completion?()
	}

	func applyToAvailableCells(_ completion: (MainFeedCollectionViewCell, IndexPath) -> Void) {
		collectionView.visibleCells.forEach { cell in
			guard let indexPath = collectionView.indexPath(for: cell) else { return }
			if let cell = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewCell {
				completion(cell, indexPath)
			}
		}
	}

	func configureIcon(_ cell: MainFeedCollectionViewCell, _ indexPath: IndexPath) {
		guard let node = coordinator.nodeFor(indexPath), let sidebarItem = node.representedObject as? SidebarItem, let sidebarItemID = sidebarItem.sidebarItemID else {
			return
		}
		cell.iconImage = IconImageCache.shared.imageFor(sidebarItemID)
	}

	func configureIcon(_ cell: MainFeedCollectionViewFolderCell, _ indexPath: IndexPath) {
		guard let node = coordinator.nodeFor(indexPath), let sidebarItem = node.representedObject as? SidebarItem, let sidebarItemID = sidebarItem.sidebarItemID else {
			return
		}
		cell.iconImage = IconImageCache.shared.imageFor(sidebarItemID)
	}

	func configureCellsForRepresentedObject(_ representedObject: AnyObject) {
		// applyToCellsForRepresentedObject(representedObject, configure)
	}

	func applyToCellsForRepresentedObject(_ representedObject: AnyObject, _ completion: (MainFeedCollectionViewCell, IndexPath) -> Void) {
		applyToAvailableCells { (cell, indexPath) in
			if let node = coordinator.nodeFor(indexPath),
			   let representedSidebarItem = representedObject as? SidebarItem,
			   let candidateSidebarItem = node.representedObject as? SidebarItem,
			   representedSidebarItem.sidebarItemID == candidateSidebarItem.sidebarItemID {
				completion(cell, indexPath)
			}
		}
	}

	func restoreSelectionIfNecessary(adjustScroll: Bool) {
		if let indexPath = coordinator.mainFeedIndexPathForCurrentTimeline() {
			if adjustScroll {
				collectionView.selectItemAndScrollIfNotVisible(at: indexPath, animations: [])
			} else {
				collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
			}
		}
	}

	// MARK: - Private

	/// Configure standard feed cells
	func configure(_ cell: MainFeedCollectionViewCell, indexPath: IndexPath) {
		guard let node = coordinator.nodeFor(indexPath) else { return }
		var indentationLevel = 0
		if let _ = node.parent?.representedObject as? Folder {
			indentationLevel = 1
		}

		if let sidebarItem = node.representedObject as? SidebarItem {
			cell.feedTitle.text = sidebarItem.nameForDisplay
			cell.unreadCount = sidebarItem.unreadCount
			cell.indentationLevel = indentationLevel
			configureIcon(cell, indexPath)
		}
	}

	/// Configure folders
	func configure(_ cell: MainFeedCollectionViewFolderCell, indexPath: IndexPath) {
		guard let node = coordinator.nodeFor(indexPath) else { return }

		if let folder = node.representedObject as? Folder {
			cell.folderTitle.text = folder.nameForDisplay
			cell.unreadCount = folder.unreadCount
			configureIcon(cell, indexPath)
		}

		if let containerID = (node.representedObject as? Container)?.containerID {
			cell.setDisclosure(isExpanded: coordinator.isExpanded(containerID), animated: false)
		}
	}

	private func headerViewForAccount(_ account: Account) -> MainFeedCollectionHeaderReusableView? {

		guard let node = coordinator.rootNode.childNodeRepresentingObject(account),
			  let sectionIndex = coordinator.rootNode.indexOfChild(node) else {
			return nil
		}
		if sectionIndex == 0 { return nil }

		return collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: sectionIndex)) as? MainFeedCollectionHeaderReusableView
	}

	private func reloadAllVisibleCells(completion: (() -> Void)? = nil) {
		guard let indexPaths = collectionView.indexPathsForSelectedItems else { return }
		collectionView.reloadItems(at: indexPaths)
		restoreSelectionIfNecessary(adjustScroll: false)
	}

	func setFilterButtonToActive() {
		filterButton.tintColor = Assets.Colors.primaryAccent
		filterButton?.accLabelText = NSLocalizedString("Selected - Filter Read Feeds", comment: "Selected - Filter Read Feeds")
	}

	func setFilterButtonToInactive() {
		filterButton.tintColor = nil
		filterButton?.accLabelText = NSLocalizedString("Filter Read Feeds", comment: "Filter Read Feeds")
	}

	// MARK: - Notifications

	@objc func preferredContentSizeCategoryDidChange() {
		IconImageCache.shared.emptyCache()
		reloadAllVisibleCells()
	}

	@objc func unreadCountDidChange(_ note: Notification) {
		updateUI()

		guard let unreadCountProvider = note.object as? UnreadCountProvider else {
			return
		}

		if let account = unreadCountProvider as? Account {
			if let headerView = headerViewForAccount(account) {
				headerView.unreadCount = account.unreadCount
			}
			return
		}

		let node: Node? = coordinator.rootNode.descendantNodeRepresentingObject(unreadCountProvider as AnyObject)

		guard let unreadCountNode = node, let indexPath = coordinator.indexPathFor(unreadCountNode) else { return }

		if let cell = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewCell {
			cell.unreadCount = unreadCountProvider.unreadCount
		}

		if let cell = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewFolderCell {
			cell.unreadCount = unreadCountProvider.unreadCount
		}
	}

	@objc func feedSettingDidChange(_ note: Notification) {
		guard let feed = note.object as? Feed, let key = note.userInfo?[Feed.SettingUserInfoKey] as? String else {
			return
		}
		if key == Feed.SettingKey.homePageURL || key == Feed.SettingKey.faviconURL {
			configureCellsForRepresentedObject(feed)
		}
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		applyToAvailableCells(configureIcon)
	}

	@objc func feedIconDidBecomeAvailable(_ note: Notification) {
		guard let feed = note.userInfo?[UserInfoKey.feed] as? Feed else {
			return
		}
		applyToCellsForRepresentedObject(feed, configureIcon(_:_:))
	}

	// MARK: - Actions

	@objc func configureContextMenu(_: Any? = nil) {
		/*
			Context Menu Order:
			1. Add Feed
			2. Add Folder
		*/

		var menuItems: [UIAction] = []

		let addFeedActionTitle = NSLocalizedString("Add Feed", comment: "Add Feed")
		let addFeedAction = UIAction(title: addFeedActionTitle, image: Assets.Images.plus) { _ in
			self.coordinator.showAddFeed()
		}
		menuItems.append(addFeedAction)

		let addFolderActionTitle = NSLocalizedString("Add Folder", comment: "Add Folder")
		let addFolderAction = UIAction(title: addFolderActionTitle, image: Assets.Images.folderOutlinePlus) { _ in
			self.coordinator.showAddFolder()
		}

		menuItems.append(addFolderAction)

		let contextMenu = UIMenu(title: NSLocalizedString("Add Item", comment: "Add Item"), image: nil, identifier: nil, options: [], children: menuItems.reversed())

		self.addNewItemButton.menu = contextMenu
	}

	@objc func refreshAccounts(_ sender: Any) {
		collectionView.refreshControl?.endRefreshing()

		// This is a hack to make sure that an error dialog doesn't interfere with dismissing the refreshControl.
		// If the error dialog appears too closely to the call to endRefreshing, then the refreshControl never disappears.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			appDelegate.manualRefresh(errorHandler: ErrorHandler.present(self))
		}
	}

	@IBAction func add(_ sender: UIBarButtonItem) {
		let title = NSLocalizedString("Add Item", comment: "Add Item")
		let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)

		let addFeedActionTitle = NSLocalizedString("Add Web Feed", comment: "Add Web Feed")
		let addFeedAction = UIAlertAction(title: addFeedActionTitle, style: .default) { _ in
			self.coordinator.showAddFeed()
		}

		let addFolderActionTitle = NSLocalizedString("Add Folder", comment: "Add Folder")
		let addFolderAction = UIAlertAction(title: addFolderActionTitle, style: .default) { _ in
			self.coordinator.showAddFolder()
		}

		alertController.addAction(addFeedAction)

		alertController.addAction(addFolderAction)
		alertController.addAction(cancelAction)

		alertController.popoverPresentationController?.barButtonItem = sender

		present(alertController, animated: true)
	}

	@IBAction func toggleFilter(_ sender: Any) {
		coordinator.toggleReadFeedsFilter()
	}

	func toggle(_ headerView: MainFeedCollectionHeaderReusableView) {
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
}

extension MainFeedCollectionViewController: MainFeedCollectionHeaderReusableViewDelegate {
	func mainFeedCollectionHeaderReusableViewDidTapDisclosureIndicator(_ view: MainFeedCollectionHeaderReusableView) {
		toggle(view)
	}
}

extension MainFeedCollectionViewController: MainFeedCollectionViewFolderCellDelegate {
	func mainFeedCollectionFolderViewCellDisclosureDidToggle(_ sender: MainFeedCollectionViewFolderCell, expanding: Bool) {
		if expanding {
			expand(sender)
		} else {
			collapse(sender)
		}
	}

	func expand(_ cell: MainFeedCollectionViewFolderCell) {
		guard let indexPath = collectionView.indexPath(for: cell), let node = coordinator.nodeFor(indexPath) else {
			return
		}
		coordinator.expand(node)
	}

	func collapse(_ cell: MainFeedCollectionViewFolderCell) {
		guard let indexPath = collectionView.indexPath(for: cell), let node = coordinator.nodeFor(indexPath) else {
			return
		}
		coordinator.collapse(node)
	}
}

extension MainFeedCollectionViewController: UIContextMenuInteractionDelegate {
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
			let cell = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: sectionIndex)) as? MainFeedCollectionHeaderReusableView else {
				return nil
		}
		return UITargetedPreview(view: cell, parameters: CroppingPreviewParameters(view: cell))
	}
}

extension MainFeedCollectionViewController {
	func makeFeedContextMenu(indexPath: IndexPath, includeDeleteRename: Bool) -> UIContextMenuConfiguration {
		return UIContextMenuConfiguration(identifier: MainFeedRowIdentifier(indexPath: indexPath), previewProvider: nil, actionProvider: { [ weak self] suggestedActions in

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
		return UIContextMenuConfiguration(identifier: MainFeedRowIdentifier(indexPath: indexPath), previewProvider: nil, actionProvider: { [weak self] suggestedActions in

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

		return UIContextMenuConfiguration(identifier: MainFeedRowIdentifier(indexPath: indexPath), previewProvider: nil, actionProvider: { suggestedActions in
			return UIMenu(title: "", children: [markAllAction])
		})
	}

	func homePageAction(indexPath: IndexPath) -> UIAction? {
		guard coordinator.homePageURLForFeed(indexPath) != nil else {
			return nil
		}

		let title = NSLocalizedString("Open Home Page", comment: "Open Home Page")
		let action = UIAction(title: title, image: Assets.Images.safari) { [weak self] action in
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
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed,
			  let url = URL(string: feed.url) else {
				  return nil
			  }

		let title = NSLocalizedString("Copy Feed URL", comment: "Copy Feed URL")
		let action = UIAction(title: title, image: Assets.Images.copy) { action in
			UIPasteboard.general.url = url
		}
		return action
	}

	func copyFeedPageAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed,
			  let url = URL(string: feed.url) else {
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
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed,
			  let homePageURL = feed.homePageURL,
			  let url = URL(string: homePageURL) else {
				  return nil
			  }

		let title = NSLocalizedString("Copy Home Page URL", comment: "Copy Home Page URL")
		let action = UIAction(title: title, image: Assets.Images.copy) { action in
			UIPasteboard.general.url = url
		}
		return action
	}

	func copyHomePageAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed,
			  let homePageURL = feed.homePageURL,
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
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed,
			feed.unreadCount > 0,
			let articles = try? feed.fetchArticles(), let contentView = self.collectionView.cellForItem(at: indexPath)?.contentView else {
				return nil
		}

		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String
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

		let action = UIAction(title: title, image: Assets.Images.trash, attributes: .destructive) { [weak self] action in
			self?.delete(indexPath: indexPath)
		}
		return action
	}

	func renameAction(indexPath: IndexPath) -> UIAction {
		let title = NSLocalizedString("Rename", comment: "Rename")
		let action = UIAction(title: title, image: Assets.Images.edit) { [weak self] action in
			self?.rename(indexPath: indexPath)
		}
		return action
	}

	func getInfoAction(indexPath: IndexPath) -> UIAction? {
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed else {
			return nil
		}

		let title = NSLocalizedString("Get Info", comment: "Get Info")
		let action = UIAction(title: title, image: Assets.Images.info) { [weak self] action in
			self?.coordinator.showFeedInspector(for: feed)
		}
		return action
	}

	func getAccountInfoAction(account: Account) -> UIAction {
		let title = NSLocalizedString("Get Info", comment: "Get Info")
		let action = UIAction(title: title, image: Assets.Images.info) { [weak self] action in
			self?.coordinator.showAccountInspector(for: account)
		}
		return action
	}

	func deactivateAccountAction(account: Account) -> UIAction {
		let title = NSLocalizedString("Deactivate", comment: "Deactivate")
		let action = UIAction(title: title, image: Assets.Images.deactivate) { action in
			account.isActive = false
		}
		return action
	}

	func getInfoAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed else {
			return nil
		}

		let title = NSLocalizedString("Get Info", comment: "Get Info")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.showFeedInspector(for: feed)
			completion(true)
		}
		return action
	}

	func markAllAsReadAction(indexPath: IndexPath) -> UIAction? {
		guard let sidebarItem = coordinator.nodeFor(indexPath)?.representedObject as? SidebarItem,
			  let contentView = self.collectionView.cellForItem(at: indexPath)?.contentView,
			  sidebarItem.unreadCount > 0 else {
				  return nil
			  }

		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, sidebarItem.nameForDisplay) as String
		let action = UIAction(title: title, image: Assets.Images.markAllAsRead) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				if let articles = try? sidebarItem.fetchUnreadArticles() {
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
		let action = UIAction(title: title, image: Assets.Images.markAllAsRead) { [weak self] action in
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
		guard let sidebarItem = coordinator.nodeFor(indexPath)?.representedObject as? SidebarItem else { return	}

		let formatString = NSLocalizedString("Rename “%@”", comment: "Rename feed")
		let title = NSString.localizedStringWithFormat(formatString as NSString, sidebarItem.nameForDisplay) as String

		let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIAlertAction(title: renameTitle, style: .default) { [weak self] action in

			guard let name = alertController.textFields?[0].text, !name.isEmpty else {
				return
			}

			if let feed = sidebarItem as? Feed {
				feed.rename(to: name) { result in
					switch result {
					case .success:
						break
					case .failure(let error):
						self?.presentError(error)
					}
				}
			} else if let folder = sidebarItem as? Folder {
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
			textField.text = sidebarItem.nameForDisplay
			textField.placeholder = NSLocalizedString("Name", comment: "Name")
			textField.clearButtonMode = .always
		}

		self.present(alertController, animated: true) {

		}

	}

	func delete(indexPath: IndexPath) {
		guard let sidebarItem = coordinator.nodeFor(indexPath)?.representedObject as? SidebarItem else { return	}

		let title: String
		let message: String
		if sidebarItem is Folder {
			title = NSLocalizedString("Delete Folder", comment: "Delete folder")
			let localizedInformativeText = NSLocalizedString("Are you sure you want to delete the “%@” folder?", comment: "Folder delete text")
			message = NSString.localizedStringWithFormat(localizedInformativeText as NSString, sidebarItem.nameForDisplay) as String
		} else  {
			title = NSLocalizedString("Delete Feed", comment: "Delete feed")
			let localizedInformativeText = NSLocalizedString("Are you sure you want to delete the “%@” feed?", comment: "Feed delete text")
			message = NSString.localizedStringWithFormat(localizedInformativeText as NSString, sidebarItem.nameForDisplay) as String
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
		} else if let feed = deleteNode.representedObject as? Feed {
			ActivityManager.cleanUp(feed)
		}

		if indexPath == coordinator.currentFeedIndexPath {
			coordinator.selectFeed(indexPath: nil)
		}

		pushUndoableCommand(deleteCommand)
		deleteCommand.perform()
	}
}
