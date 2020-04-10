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

class MasterFeedViewController: UITableViewController, UndoableCommandRunner {

	@IBOutlet weak var filterButton: UIBarButtonItem!
	private var refreshProgressView: RefreshProgressView?
	@IBOutlet weak var addNewItemButton: UIBarButtonItem!

	private let operationQueue = MainThreadOperationQueue()
	lazy var dataSource = makeDataSource()
	
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
		
		// If you don't have an empty table header, UIKit tries to help out by putting one in for you
		// that makes a gap between the first section header and the navigation bar
		var frame = CGRect.zero
		frame.size.height = .leastNormalMagnitude
		tableView.tableHeaderView = UIView(frame: frame)
		
		tableView.register(MasterFeedTableViewSectionHeader.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		tableView.dataSource = dataSource
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

		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
		configureToolbar()
		becomeFirstResponder()

	}

	override func viewWillAppear(_ animated: Bool) {
		updateUI()
		super.viewWillAppear(animated)
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
		if let coordinator = representedObject as? SceneCoordinator, let feed = coordinator.timelineFeed {
			node = coordinator.rootNode.descendantNodeRepresentingObject(feed as AnyObject)
		} else {
			node = coordinator.rootNode.descendantNodeRepresentingObject(representedObject as AnyObject)
		}

		if let node = node, dataSource.indexPath(for: node) != nil {
			self.reloadNode(node)
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
		applyChanges(animated: false)
	}
	
	@objc func willEnterForeground(_ note: Notification) {
		updateUI()
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
		
		if let webFeed = dataSource.itemIdentifier(for: indexPath)?.representedObject as? WebFeed {
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
		guard let node = dataSource.itemIdentifier(for: indexPath) else {
			return nil
		}
		if node.representedObject is WebFeed {
			return makeFeedContextMenu(node: node, indexPath: indexPath, includeDeleteRename: true)
		} else if node.representedObject is Folder {
			return makeFolderContextMenu(node: node, indexPath: indexPath)
		} else if node.representedObject is PseudoFeed  {
			return makePseudoFeedContextMenu(node: node, indexPath: indexPath)
		} else {
			return nil
		}
	}
	
	override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
		guard let nodeUniqueId = configuration.identifier as? Int,
			let node = coordinator.rootNode.descendantNode(where: { $0.uniqueID == nodeUniqueId }),
			let indexPath = dataSource.indexPath(for: node),
			let cell = tableView.cellForRow(at: indexPath) else {
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
		
		guard let draggedNode = dataSource.itemIdentifier(for: sourceIndexPath) else {
			assertionFailure("This should never happen")
			return sourceIndexPath
		}
		
		// If there is no destination node, we are dragging onto an empty Account
		guard let destNode = dataSource.itemIdentifier(for: destIndexPath), let parentNode = destNode.parent else {
			return proposedDestinationIndexPath
		}
		
		// If this is a folder and isn't expanded or doesn't have any entries, let the users drop on it
		if destNode.representedObject is Folder && (destNode.numberOfChildNodes == 0 || !coordinator.isExpanded(destNode)) {
			return proposedDestinationIndexPath
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

		sortedNodes.remove(at: index)

		if index == 0 {
			
			if parentNode.representedObject is Account {
				return IndexPath(row: 0, section: destIndexPath.section)
			} else {
				let candidateIndexPath = dataSource.indexPath(for: sortedNodes[index])!
				let movementAdjustment = sourceIndexPath < destIndexPath ? 1 : 0
				return IndexPath(row: candidateIndexPath.row - movementAdjustment, section: candidateIndexPath.section)
			}
			
		} else {
			
			if index >= sortedNodes.count {
				let lastSortedIndexPath = dataSource.indexPath(for: sortedNodes[sortedNodes.count - 1])!
				let movementAdjustment = sourceIndexPath > destIndexPath ? 1 : 0
				return IndexPath(row: lastSortedIndexPath.row + movementAdjustment, section: lastSortedIndexPath.section)
			} else {
				let movementAdjustment = sourceIndexPath < destIndexPath ? 1 : 0
				return dataSource.indexPath(for: sortedNodes[index - movementAdjustment])!
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
		coordinator.showAdd(.feed)
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
		if let indexPath = coordinator.currentFeedIndexPath, let node = dataSource.itemIdentifier(for: indexPath) {
			coordinator.expand(node)
			self.applyChanges(animated: true) {
				self.reloadAllVisibleCells()
			}
		}
	}
	
	@objc func collapseSelectedRows(_ sender: Any?) {
		if let indexPath = coordinator.currentFeedIndexPath, let node = dataSource.itemIdentifier(for: indexPath) {
			coordinator.collapse(node)
			self.applyChanges(animated: true) {
				self.reloadAllVisibleCells()
			}
		}
	}
	
	@objc func expandAll(_ sender: Any?) {
		coordinator.expandAllSectionsAndFolders()
		self.applyChanges(animated: true) {
			self.reloadAllVisibleCells()
		}
	}
	
	@objc func collapseAllExceptForGroupItems(_ sender: Any?) {
		coordinator.collapseAllFolders()
		self.applyChanges(animated: true) {
			self.reloadAllVisibleCells()
		}
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
		operationQueue.add(UpdateSelectionOperation(coordinator: coordinator, dataSource: dataSource, tableView: tableView, animations: animations))
	}

	func reloadFeeds(initialLoad: Bool, completion: (() -> Void)? = nil) {
		updateUI()

		// We have to reload all the visible cells because if we got here by doing a table cell move,
		// then the table itself is in a weird state.  This is because we do unusual things like allowing
		// drops on a "folder" that should cause the dropped cell to disappear.
		applyChanges(animated: !initialLoad) { [weak self] in
			if !initialLoad {
				self?.reloadAllVisibleCells(completion: completion)
			} else {
				completion?()
			}
		}
	}
	
	func updateUI() {
		if coordinator.isReadFeedsFiltered {
			setFilterButtonToActive()
		} else {
			setFilterButtonToInactive()
		}
		refreshProgressView?.updateRefreshLabel()
		addNewItemButton?.isEnabled = !AccountManager.shared.activeAccounts.isEmpty
	}
	
	func focus() {
		becomeFirstResponder()
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
			let accountInfoAction = self.getAccountInfoAction(account: account)
			let deactivateAction = self.deactivateAccountAction(account: account)

			var actions = [accountInfoAction, deactivateAction]

			if let markAllAction = self.markAllAsReadAction(account: account) {
				actions.insert(markAllAction, at: 1)
			}

            return UIMenu(title: "", children: actions)
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
	
	func reloadNode(_ node: Node) {
		var snapshot = dataSource.snapshot()
		snapshot.reloadItems([node])
		queueApply(snapshot: snapshot, animatingDifferences: false) { [weak self] in
			self?.restoreSelectionIfNecessary(adjustScroll: false)
		}
	}
	
	func applyChanges(animated: Bool, adjustScroll: Bool = false, completion: (() -> Void)? = nil) {
        var snapshot = NSDiffableDataSourceSnapshot<Node, Node>()
		let sectionNodes = coordinator.rootNode.childNodes
		snapshot.appendSections(sectionNodes)

		for (index, sectionNode) in sectionNodes.enumerated() {
			let shadowTableNodes = coordinator.shadowNodesFor(section: index)
			snapshot.appendItems(shadowTableNodes, toSection: sectionNode)
		}
        
		queueApply(snapshot: snapshot, animatingDifferences: animated) { [weak self] in
			self?.restoreSelectionIfNecessary(adjustScroll: adjustScroll)
			completion?()
		}
	}
	
	func queueApply(snapshot: NSDiffableDataSourceSnapshot<Node, Node>, animatingDifferences: Bool = true, completion: (() -> Void)? = nil) {
		let operation = MasterFeedDataSourceOperation(dataSource: dataSource, snapshot: snapshot, animating: animatingDifferences)
		operation.completionBlock = { _ in
			completion?()
		}
		operationQueue.add(operation)
	}


    func makeDataSource() -> MasterFeedDataSource {
		let dataSource = MasterFeedDataSource(tableView: tableView, cellProvider: { [weak self] tableView, indexPath, node in
			let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterFeedTableViewCell
			self?.configure(cell, node)
			return cell
		})
		dataSource.defaultRowAnimation = .middle
		return dataSource
    }

	func resetEstimatedRowHeight() {
		let titleLabel = NonIntrinsicLabel()
		titleLabel.text = "But I must explain"
		
		let unreadCountView = MasterFeedUnreadCountView()
		unreadCountView.unreadCount = 10
		
		let layout = MasterFeedTableViewCellLayout(cellWidth: tableView.bounds.size.width, insets: tableView.safeAreaInsets, label: titleLabel, unreadCountView: unreadCountView, showingEditingControl: false, indent: false, shouldShowDisclosure: false)
		tableView.estimatedRowHeight = layout.height
	}
	
	func configure(_ cell: MasterFeedTableViewCell, _ node: Node) {
		
		cell.delegate = self
		if node.representedObject is Folder {
			cell.indentationLevel = 0
		} else {
			cell.indentationLevel = 1
		}
		cell.setDisclosure(isExpanded: coordinator.isExpanded(node), animated: false)
		cell.isDisclosureAvailable = node.canHaveChildNodes
		
		cell.name = nameFor(node)
		cell.unreadCount = coordinator.unreadCountFor(node)
		configureIcon(cell, node)
		
		guard let indexPath = dataSource.indexPath(for: node) else { return }
		let rowsInSection = tableView.numberOfRows(inSection: indexPath.section)
		if indexPath.row == rowsInSection - 1 {
			cell.isSeparatorShown = false
		} else {
			cell.isSeparatorShown = true
		}
		
	}
	
	func configureIcon(_ cell: MasterFeedTableViewCell, _ node: Node) {
		cell.iconImage = imageFor(node)
	}

	func imageFor(_ node: Node) -> IconImage? {
		if let webFeed = node.representedObject as? WebFeed {
			
			let feedIconImage = appDelegate.webFeedIconDownloader.icon(for: webFeed)
			if feedIconImage != nil {
				return feedIconImage
			}
			
			if let faviconImage = appDelegate.faviconDownloader.faviconAsIcon(for: webFeed) {
				return faviconImage
			}
			
		}
		
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

	func applyToCellsForRepresentedObject(_ representedObject: AnyObject, _ completion: (MasterFeedTableViewCell, Node) -> Void) {
		applyToAvailableCells { (cell, node) in
			if node.representedObject === representedObject {
				completion(cell, node)
			}
		}
	}
	
	func applyToAvailableCells(_ completion: (MasterFeedTableViewCell, Node) -> Void) {
		tableView.visibleCells.forEach { cell in
			guard let indexPath = tableView.indexPath(for: cell), let node = dataSource.itemIdentifier(for: indexPath) else {
				return
			}
			completion(cell as! MasterFeedTableViewCell, node)
		}
	}

	private func reloadAllVisibleCells(completion: (() -> Void)? = nil) {
		let visibleNodes = tableView.indexPathsForVisibleRows!.compactMap { return dataSource.itemIdentifier(for: $0) }
		reloadCells(visibleNodes, completion: completion)
	}
	
	private func reloadCells(_ nodes: [Node], completion: (() -> Void)? = nil) {
		var snapshot = dataSource.snapshot()
		snapshot.reloadItems(nodes)
		queueApply(snapshot: snapshot, animatingDifferences: false) { [weak self] in
			self?.restoreSelectionIfNecessary(adjustScroll: false)
			completion?()
		}
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
			self.applyChanges(animated: true)
		} else {
			headerView.disclosureExpanded = true
			coordinator.expand(sectionNode)
			self.applyChanges(animated: true)
		}
	}

	func expand(_ cell: MasterFeedTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell), let node = dataSource.itemIdentifier(for: indexPath) else {
			return
		}
		coordinator.expand(node)
		applyChanges(animated: true)
	}

	func collapse(_ cell: MasterFeedTableViewCell) {
		guard let indexPath = tableView.indexPath(for: cell), let node = dataSource.itemIdentifier(for: indexPath) else {
			return
		}
		coordinator.collapse(node)
		applyChanges(animated: true)
	}

	func makeFeedContextMenu(node: Node, indexPath: IndexPath, includeDeleteRename: Bool) -> UIContextMenuConfiguration {
		return UIContextMenuConfiguration(identifier: node.uniqueID as NSCopying, previewProvider: nil, actionProvider: { [ weak self] suggestedActions in
			
			guard let self = self else { return nil }
			
			var actions = [UIAction]()
			
			if let inspectorAction = self.getInfoAction(indexPath: indexPath) {
				actions.append(inspectorAction)
			}
			
			if let homePageAction = self.homePageAction(indexPath: indexPath) {
				actions.append(homePageAction)
			}
			
			if let copyFeedPageAction = self.copyFeedPageAction(indexPath: indexPath) {
				actions.append(copyFeedPageAction)
			}
			
			if let copyHomePageAction = self.copyHomePageAction(indexPath: indexPath) {
				actions.append(copyHomePageAction)
			}

			if let markAllAction = self.markAllAsReadAction(indexPath: indexPath) {
				actions.append(markAllAction)
			}
			
			if includeDeleteRename {
				actions.append(self.renameAction(indexPath: indexPath))
				actions.append(self.deleteAction(indexPath: indexPath))
			}
			
			return UIMenu(title: "", children: actions)
			
		})
		
	}
	
	func makeFolderContextMenu(node: Node, indexPath: IndexPath) -> UIContextMenuConfiguration {
		return UIContextMenuConfiguration(identifier: node.uniqueID as NSCopying, previewProvider: nil, actionProvider: { [weak self] suggestedActions in

			guard let self = self else { return nil }
			
			var actions = [UIAction]()
			actions.append(self.deleteAction(indexPath: indexPath))
			actions.append(self.renameAction(indexPath: indexPath))

			if let markAllAction = self.markAllAsReadAction(indexPath: indexPath) {
				actions.append(markAllAction)
			}
			
			return UIMenu(title: "", children: actions)

		})
	}

	func makePseudoFeedContextMenu(node: Node, indexPath: IndexPath) -> UIContextMenuConfiguration? {
		guard let markAllAction = self.markAllAsReadAction(indexPath: indexPath) else {
			return nil
		}

		return UIContextMenuConfiguration(identifier: node.uniqueID as NSCopying, previewProvider: nil, actionProvider: { suggestedActions in
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
		guard let node = dataSource.itemIdentifier(for: indexPath),
			let feed = node.representedObject as? WebFeed,
			let url = URL(string: feed.url) else {
				return nil
		}
		
		let title = NSLocalizedString("Copy Feed URL", comment: "Copy Feed URL")
		let action = UIAction(title: title, image: AppAssets.copyImage) { action in
			UIPasteboard.general.url = url
		}
		return action
	}
	
	func copyFeedPageAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let node = dataSource.itemIdentifier(for: indexPath),
			let feed = node.representedObject as? WebFeed,
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
		guard let node = dataSource.itemIdentifier(for: indexPath),
			let feed = node.representedObject as? WebFeed,
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
	
	func copyHomePageAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let node = dataSource.itemIdentifier(for: indexPath),
			let feed = node.representedObject as? WebFeed,
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
		guard let node = dataSource.itemIdentifier(for: indexPath),
			coordinator.unreadCountFor(node) > 0,
			let feed = node.representedObject as? WebFeed,
			let articles = try? feed.fetchArticles() else {
				return nil
		}
		
		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String
		let cancel = {
			completion(true)
		}
		
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, cancelCompletion: cancel) { [weak self] in
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
		guard let node = dataSource.itemIdentifier(for: indexPath), let feed = node.representedObject as? WebFeed else {
			return nil
		}
		
		let title = NSLocalizedString("Get Info", comment: "Get Info")
		let action = UIAction(title: title, image: AppAssets.infoImage) { [weak self] action in
			self?.coordinator.showFeedInspector(for: feed)
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
		guard let node = dataSource.itemIdentifier(for: indexPath), let feed = node.representedObject as? WebFeed else {
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
		guard let node = dataSource.itemIdentifier(for: indexPath),
			coordinator.unreadCountFor(node) > 0 else {
			return nil
		}

		guard let articleFetcher = node.representedObject as? Feed,
			let fetchedArticles = try? articleFetcher.fetchArticles() else {
			return nil
		}

		let articles = Array(fetchedArticles)
		return markAllAsReadAction(articles: articles, nameForDisplay: articleFetcher.nameForDisplay)
	}

	func markAllAsReadAction(account: Account) -> UIAction? {
		guard let fetchedArticles = try? account.fetchArticles(FetchType.unread) else {
			return nil
		}

		let articles = Array(fetchedArticles)
		return markAllAsReadAction(articles: articles, nameForDisplay: account.nameForDisplay)
	}

	func markAllAsReadAction(articles: [Article], nameForDisplay: String) -> UIAction? {
		guard articles.canMarkAllAsRead() else {
			return nil
		}

		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, nameForDisplay) as String

		let action = UIAction(title: title, image: AppAssets.markAllAsReadImage) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title) { [weak self] in
				self?.coordinator.markAllAsRead(articles)
			}
		}

		return action
	}
	
	func rename(indexPath: IndexPath) {
		
		let name = (dataSource.itemIdentifier(for: indexPath)?.representedObject as? DisplayNameProvider)?.nameForDisplay ?? ""
		let formatString = NSLocalizedString("Rename “%@”", comment: "Feed finder")
		let title = NSString.localizedStringWithFormat(formatString as NSString, name) as String
		
		let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
		
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIAlertAction(title: renameTitle, style: .default) { [weak self] action in
			
			guard let node = self?.dataSource.itemIdentifier(for: indexPath),
				let name = alertController.textFields?[0].text,
				!name.isEmpty else {
					return
			}
			
			if let feed = node.representedObject as? WebFeed {
				feed.rename(to: name) { result in
					switch result {
					case .success:
						break
					case .failure(let error):
						self?.presentError(error)
					}
				}
			} else if let folder = node.representedObject as? Folder {
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
		
		alertController.addTextField() { textField in
			textField.text = name
			textField.placeholder = NSLocalizedString("Name", comment: "Name")
		}
		
		self.present(alertController, animated: true) {
			
		}
		
	}
	
	func delete(indexPath: IndexPath) {
		guard let undoManager = undoManager,
			let deleteNode = dataSource.itemIdentifier(for: indexPath),
			let deleteCommand = DeleteCommand(nodesToDelete: [deleteNode], undoManager: undoManager, errorHandler: ErrorHandler.present(self))
				else {
					return
		}

		if let folder = deleteNode.representedObject as? Folder {
			ActivityManager.cleanUp(folder)
		} else if let feed = deleteNode.representedObject as? WebFeed {
			ActivityManager.cleanUp(feed)
		}
		
		pushUndoableCommand(deleteCommand)
		deleteCommand.perform()
		
		if indexPath == coordinator.currentFeedIndexPath {
			coordinator.selectFeed(indexPath: nil)
		}
		
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
