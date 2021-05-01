//
//  MasterTimelineViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account
import Articles

class MasterTimelineViewController: UITableViewController, UndoableCommandRunner {

	private var numberOfTextLines = 0
	private var iconSize = IconSize.medium
	private lazy var feedTapGestureRecognizer = UITapGestureRecognizer(target: self, action:#selector(showFeedInspector(_:)))
	
	private var refreshProgressView: RefreshProgressView?

	@IBOutlet weak var markAllAsReadButton: UIBarButtonItem!

	private var filterButton: UIBarButtonItem!
	private var firstUnreadButton: UIBarButtonItem!

	private lazy var dataSource = makeDataSource()
	private let searchController = UISearchController(searchResultsController: nil)
	
	weak var coordinator: SceneCoordinator!
	var undoableCommands = [UndoableCommand]()
	let scrollPositionQueue = CoalescingQueue(name: "Timeline Scroll Position", interval: 0.3, maxInterval: 1.0)

	private let keyboardManager = KeyboardManager(type: .timeline)
	override var keyCommands: [UIKeyCommand]? {
		return keyboardManager.keyCommands
	}
	
	override var canBecomeFirstResponder: Bool {
		return true
	}

	override func viewDidLoad() {
		
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

		// Initialize Programmatic Buttons
		filterButton = UIBarButtonItem(image: AppAssets.filterInactiveImage, style: .plain, target: self, action: #selector(toggleFilter(_:)))
		firstUnreadButton = UIBarButtonItem(image: AppAssets.nextUnreadArticleImage, style: .plain, target: self, action: #selector(firstUnread(_:)))
		
		// Setup the Search Controller
		searchController.delegate = self
		searchController.searchResultsUpdater = self
		searchController.obscuresBackgroundDuringPresentation = false
		searchController.searchBar.delegate = self
		searchController.searchBar.placeholder = NSLocalizedString("Search Articles", comment: "Search Articles")
		searchController.searchBar.scopeButtonTitles = [
			NSLocalizedString("Here", comment: "Here"),
			NSLocalizedString("All Articles", comment: "All Articles")
		]
		navigationItem.searchController = searchController
		definesPresentationContext = true

		// Configure the table
		tableView.dataSource = dataSource
		numberOfTextLines = AppDefaults.shared.timelineNumberOfLines
		iconSize = AppDefaults.shared.timelineIconSize
		resetEstimatedRowHeight()
		
		if let titleView = Bundle.main.loadNibNamed("MasterTimelineTitleView", owner: self, options: nil)?[0] as? MasterTimelineTitleView {
			navigationItem.titleView = titleView
		}
		
		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
		configureToolbar()
		resetUI(resetScroll: true)
		
		// Load the table and then scroll to the saved position if available
		applyChanges(animated: false) {
			if let restoreIndexPath = self.coordinator.timelineMiddleIndexPath {
				self.tableView.scrollToRow(at: restoreIndexPath, at: .middle, animated: false)
			}
		}
		
		// Disable swipe back on iPad Mice
		if #available(iOS 13.4, *) {
			guard let gesture = self.navigationController?.interactivePopGestureRecognizer as? UIPanGestureRecognizer else {
				return
			}
			gesture.allowedScrollTypesMask = []
		}
		
	}
	
	override func viewWillAppear(_ animated: Bool) {
		// If the nav bar is hidden, fade it in to avoid it showing stuff as it is getting laid out
		if navigationController?.navigationBar.isHidden ?? false {
			navigationController?.navigationBar.alpha = 0
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(true)
		coordinator.isTimelineViewControllerPending = false

		if navigationController?.navigationBar.alpha == 0 {
			UIView.animate(withDuration: 0.5) {
				self.navigationController?.navigationBar.alpha = 1
			}
		}
	}
	
	// MARK: Actions
	@IBAction func toggleFilter(_ sender: Any) {
		coordinator.toggleReadArticlesFilter()
	}
	
	@IBAction func markAllAsRead(_ sender: Any) {
		let title = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")
		
		if let source = sender as? UIBarButtonItem {
			MarkAsReadAlertController.confirm(self, coordinator: coordinator, confirmTitle: title, sourceType: source) { [weak self] in
				self?.coordinator.markAllAsReadInTimeline()
			}
		}
		
		if let _ = sender as? UIKeyCommand {
			guard let indexPath = tableView.indexPathForSelectedRow, let contentView = tableView.cellForRow(at: indexPath)?.contentView else {
				return
			}
			
			MarkAsReadAlertController.confirm(self, coordinator: coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				self?.coordinator.markAllAsReadInTimeline()
			}
		}
	}
	
	@IBAction func firstUnread(_ sender: Any) {
		coordinator.selectFirstUnread()
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
		coordinator.selectPrevArticle()
	}

	@objc func selectNextDown(_ sender: Any?) {
		coordinator.selectNextArticle()
	}

	@objc func navigateToSidebar(_ sender: Any?) {
		coordinator.navigateToFeeds()
	}
	
	@objc func navigateToDetail(_ sender: Any?) {
		coordinator.navigateToDetail()
	}
	
	@objc func showFeedInspector(_ sender: Any?) {
		coordinator.showFeedInspector()
	}

	// MARK: API
	
	func restoreSelectionIfNecessary(adjustScroll: Bool) {
		if let article = coordinator.currentArticle, let indexPath = dataSource.indexPath(for: article) {
			if adjustScroll {
				tableView.selectRowAndScrollIfNotVisible(at: indexPath, animations: [])
			} else {
				tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
			}
		}
	}

	func reinitializeArticles(resetScroll: Bool) {
		resetUI(resetScroll: resetScroll)
	}
	
	func reloadArticles(animated: Bool) {
		applyChanges(animated: animated)
	}
	
	func updateArticleSelection(animations: Animations) {
		if let article = coordinator.currentArticle, let indexPath = dataSource.indexPath(for: article) {
			if tableView.indexPathForSelectedRow != indexPath {
				tableView.selectRowAndScrollIfNotVisible(at: indexPath, animations: animations)
			}
		} else {
			tableView.selectRow(at: nil, animated: animations.contains(.select), scrollPosition: .none)
		}
		
		updateUI()
	}

	func updateUI() {
		refreshProgressView?.update()
		updateTitleUnreadCount()
		updateToolbar()
	}
	
	func hideSearch() {
		navigationItem.searchController?.isActive = false
	}

	func showSearchAll() {
		navigationItem.searchController?.isActive = true
		navigationItem.searchController?.searchBar.selectedScopeButtonIndex = 1
		navigationItem.searchController?.searchBar.becomeFirstResponder()
	}
	
	func focus() {
		becomeFirstResponder()
	}

	// MARK: - Table view

	override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }
		guard !article.status.read || article.isAvailableToMarkUnread else { return nil }

		// Set up the read action
		let readTitle = article.status.read ?
			NSLocalizedString("Unread", comment: "Unread") :
			NSLocalizedString("Read", comment: "Read")
		
		let readAction = UIContextualAction(style: .normal, title: readTitle) { [weak self] (action, view, completion) in
			self?.coordinator.toggleRead(article)
			completion(true)
		}
		
		readAction.image = article.status.read ? AppAssets.circleClosedImage : AppAssets.circleOpenImage
		readAction.backgroundColor = AppAssets.primaryAccentColor
		
		return UISwipeActionsConfiguration(actions: [readAction])
	}
	
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		
		guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }
		
		// Set up the star action
		let starTitle = article.status.starred ?
			NSLocalizedString("Unstar", comment: "Unstar") :
			NSLocalizedString("Star", comment: "Star")
		
		let starAction = UIContextualAction(style: .normal, title: starTitle) { [weak self] (action, view, completion) in
			self?.coordinator.toggleStar(article)
			completion(true)
		}
		
		starAction.image = article.status.starred ? AppAssets.starOpenImage : AppAssets.starClosedImage
		starAction.backgroundColor = AppAssets.starColor
		
		// Set up the read action
		let moreTitle = NSLocalizedString("More", comment: "More")
		let moreAction = UIContextualAction(style: .normal, title: moreTitle) { [weak self] (action, view, completion) in
			
			if let self = self {
			
				let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
				if let popoverController = alert.popoverPresentationController {
					popoverController.sourceView = view
					popoverController.sourceRect = CGRect(x: view.frame.size.width/2, y: view.frame.size.height/2, width: 1, height: 1)
				}

				if let action = self.markAboveAsReadAlertAction(article, indexPath: indexPath, completion: completion) {
					alert.addAction(action)
				}

				if let action = self.markBelowAsReadAlertAction(article, indexPath: indexPath, completion: completion) {
					alert.addAction(action)
				}
				
				if let action = self.discloseFeedAlertAction(article, completion: completion) {
					alert.addAction(action)
				}
				
				if let action = self.markAllInFeedAsReadAlertAction(article, indexPath: indexPath, completion: completion) {
					alert.addAction(action)
				}

				if let action = self.openInBrowserAlertAction(article, completion: completion) {
					alert.addAction(action)
				}

				if let action = self.shareAlertAction(article, indexPath: indexPath, completion: completion) {
					alert.addAction(action)
				}

				let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
				alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
					completion(true)
				})

				self.present(alert, animated: true)
				
			}
			
		}
		
		moreAction.image = AppAssets.moreImage
		moreAction.backgroundColor = UIColor.systemGray

		return UISwipeActionsConfiguration(actions: [starAction, moreAction])
		
	}

	override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

		guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }
		
		return UIContextMenuConfiguration(identifier: indexPath.row as NSCopying, previewProvider: nil, actionProvider: { [weak self] suggestedActions in

			guard let self = self else { return nil }
			
			var menuElements = [UIMenuElement]()
			
			var markActions = [UIAction]()
			if let action = self.toggleArticleReadStatusAction(article) {
				markActions.append(action)
			}
			markActions.append(self.toggleArticleStarStatusAction(article))
			if let action = self.markAboveAsReadAction(article, indexPath: indexPath) {
				markActions.append(action)
			}
			if let action = self.markBelowAsReadAction(article, indexPath: indexPath) {
				markActions.append(action)
			}
			menuElements.append(UIMenu(title: "", options: .displayInline, children: markActions))
			
			var secondaryActions = [UIAction]()
			if let action = self.discloseFeedAction(article) {
				secondaryActions.append(action)
			}
			if let action = self.markAllInFeedAsReadAction(article, indexPath: indexPath) {
				secondaryActions.append(action)
			}
			if !secondaryActions.isEmpty {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: secondaryActions))
			}
			
			var copyActions = [UIAction]()
			if let action = self.copyArticleURLAction(article) {
				copyActions.append(action)
			}
			if let action = self.copyExternalURLAction(article) {
				copyActions.append(action)
			}
			if !copyActions.isEmpty {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: copyActions))
			}
			
			if let action = self.openInBrowserAction(article) {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: [action]))
			}
			
			if let action = self.shareAction(article, indexPath: indexPath) {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: [action]))
			}
			
			return UIMenu(title: "", children: menuElements)

		})
		
	}

	override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
		guard let row = configuration.identifier as? Int,
			let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) else {
				return nil
		}
		
		return UITargetedPreview(view: cell, parameters: CroppingPreviewParameters(view: cell))
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		becomeFirstResponder()
		let article = dataSource.itemIdentifier(for: indexPath)
		coordinator.selectArticle(article, animations: [.scroll, .select, .navigation])
	}
	
	override func scrollViewDidScroll(_ scrollView: UIScrollView) {
		scrollPositionQueue.add(self, #selector(scrollPositionDidChange))
	}
	
	// MARK: Notifications

	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		updateUI()
	}
	
	@objc func statusesDidChange(_ note: Notification) {
		guard let articleIDs = note.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String>, !articleIDs.isEmpty else {
			return
		}

		let visibleArticles = tableView.indexPathsForVisibleRows!.compactMap { return dataSource.itemIdentifier(for: $0) }
		let visibleUpdatedArticles = visibleArticles.filter { articleIDs.contains($0.articleID) }

		for article in visibleUpdatedArticles {
			if let indexPath = dataSource.indexPath(for: article) {
				if let cell = tableView.cellForRow(at: indexPath) as? MasterTimelineTableViewCell {
					configure(cell, article: article)
				}
			}
		}
	}

	@objc func webFeedIconDidBecomeAvailable(_ note: Notification) {
		
		if let titleView = navigationItem.titleView as? MasterTimelineTitleView {
			titleView.iconView.iconImage = coordinator.timelineIconImage
		}
		
		guard let feed = note.userInfo?[UserInfoKey.webFeed] as? WebFeed else {
			return
		}
		tableView.indexPathsForVisibleRows?.forEach { indexPath in
			guard let article = dataSource.itemIdentifier(for: indexPath) else {
				return
			}
			if article.webFeed == feed, let cell = tableView.cellForRow(at: indexPath) as? MasterTimelineTableViewCell, let image = iconImageFor(article) {
				cell.setIconImage(image)
			}
		}
	}

	@objc func avatarDidBecomeAvailable(_ note: Notification) {
		guard coordinator.showIcons, let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
			return
		}
		tableView.indexPathsForVisibleRows?.forEach { indexPath in
			guard let article = dataSource.itemIdentifier(for: indexPath), let authors = article.authors, !authors.isEmpty else {
				return
			}
			for author in authors {
				if author.avatarURL == avatarURL, let cell = tableView.cellForRow(at: indexPath) as? MasterTimelineTableViewCell, let image = iconImageFor(article) {
					cell.setIconImage(image)
				}
			}
		}
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		if let titleView = navigationItem.titleView as? MasterTimelineTitleView {
			titleView.iconView.iconImage = coordinator.timelineIconImage
		}
		if coordinator.showIcons {
			queueReloadAvailableCells()
		}
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		DispatchQueue.main.async {
			if self.numberOfTextLines != AppDefaults.shared.timelineNumberOfLines || self.iconSize != AppDefaults.shared.timelineIconSize {
				self.numberOfTextLines = AppDefaults.shared.timelineNumberOfLines
				self.iconSize = AppDefaults.shared.timelineIconSize
				self.resetEstimatedRowHeight()
				self.reloadAllVisibleCells()
			}
			self.updateToolbar()
		}
	}
	
	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		reloadAllVisibleCells()
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		if let titleView = navigationItem.titleView as? MasterTimelineTitleView {
			titleView.label.text = coordinator.timelineFeed?.nameForDisplay
		}
	}
	
	@objc func willEnterForeground(_ note: Notification) {
		updateUI()
	}
	
	@objc func scrollPositionDidChange() {
		coordinator.timelineMiddleIndexPath = tableView.middleVisibleRow()
	}
	
	// MARK: Reloading
	
	func queueReloadAvailableCells() {
		CoalescingQueue.standard.add(self, #selector(reloadAllVisibleCells))
	}

	@objc private func reloadAllVisibleCells() {
		let visibleArticles = tableView.indexPathsForVisibleRows!.compactMap { return dataSource.itemIdentifier(for: $0) }
		reloadCells(visibleArticles)
	}
	
	private func reloadCells(_ articles: [Article]) {
		var snapshot = dataSource.snapshot()
		snapshot.reloadItems(articles)
		dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
			self?.restoreSelectionIfNecessary(adjustScroll: false)
		}
	}
	
	// MARK: Cell Configuring

	private func resetEstimatedRowHeight() {
		
		let longTitle = "But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?"
		
		let prototypeID = "prototype"
		let status = ArticleStatus(articleID: prototypeID, read: false, starred: false, dateArrived: Date())
		let prototypeArticle = Article(accountID: prototypeID, articleID: prototypeID, webFeedID: prototypeID, uniqueID: prototypeID, title: longTitle, contentHTML: nil, contentText: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, datePublished: nil, dateModified: nil, authors: nil, status: status)
		
		let prototypeCellData = MasterTimelineCellData(article: prototypeArticle, showFeedName: .feed, feedName: "Prototype Feed Name", byline: nil, iconImage: nil, showIcon: false, featuredImage: nil, numberOfLines: numberOfTextLines, iconSize: iconSize)
		
		if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
			let layout = MasterTimelineAccessibilityCellLayout(width: tableView.bounds.width, insets: tableView.safeAreaInsets, cellData: prototypeCellData)
			tableView.estimatedRowHeight = layout.height
		} else {
			let layout = MasterTimelineDefaultCellLayout(width: tableView.bounds.width, insets: tableView.safeAreaInsets, cellData: prototypeCellData)
			tableView.estimatedRowHeight = layout.height
		}
		
	}
	
}

// MARK: Searching

extension MasterTimelineViewController: UISearchControllerDelegate {

	func willPresentSearchController(_ searchController: UISearchController) {
		coordinator.beginSearching()
		searchController.searchBar.showsScopeBar = true
	}

	func willDismissSearchController(_ searchController: UISearchController) {
		coordinator.endSearching()
		searchController.searchBar.showsScopeBar = false
	}

}

extension MasterTimelineViewController: UISearchResultsUpdating {

	func updateSearchResults(for searchController: UISearchController) {
		let searchScope = SearchScope(rawValue: searchController.searchBar.selectedScopeButtonIndex)!
		coordinator.searchArticles(searchController.searchBar.text!, searchScope)
	}

}

extension MasterTimelineViewController: UISearchBarDelegate {
	func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
		let searchScope = SearchScope(rawValue: selectedScope)!
		coordinator.searchArticles(searchBar.text!, searchScope)
	}
}

// MARK: Private

private extension MasterTimelineViewController {

	func configureToolbar() {
		
		guard !coordinator.isThreePanelMode else {
			return
		}
		
		guard let refreshProgressView = Bundle.main.loadNibNamed("RefreshProgressView", owner: self, options: nil)?[0] as? RefreshProgressView else {
			return
		}

		self.refreshProgressView = refreshProgressView
		let refreshProgressItemButton = UIBarButtonItem(customView: refreshProgressView)
		toolbarItems?.insert(refreshProgressItemButton, at: 2)
	}

	func resetUI(resetScroll: Bool) {
		
		title = coordinator.timelineFeed?.nameForDisplay ?? "Timeline"

		if let titleView = navigationItem.titleView as? MasterTimelineTitleView {
			let timelineIconImage = coordinator.timelineIconImage
			titleView.iconView.iconImage = timelineIconImage
			if let preferredColor = timelineIconImage?.preferredColor {
				titleView.iconView.tintColor = UIColor(cgColor: preferredColor)
			} else {
				titleView.iconView.tintColor = nil
			}
			
			titleView.label.text = coordinator.timelineFeed?.nameForDisplay
			updateTitleUnreadCount()

			if coordinator.timelineFeed is WebFeed {
				titleView.buttonize()
				titleView.addGestureRecognizer(feedTapGestureRecognizer)
			} else {
				titleView.debuttonize()
				titleView.removeGestureRecognizer(feedTapGestureRecognizer)
			}
			
			navigationItem.titleView = titleView
		}

		switch coordinator.timelineDefaultReadFilterType {
		case .none, .read:
			navigationItem.rightBarButtonItem = filterButton
		case .alwaysRead:
			navigationItem.rightBarButtonItem = nil
		}
		
		if coordinator.isReadArticlesFiltered {
			filterButton?.image = AppAssets.filterActiveImage
			filterButton?.accLabelText = NSLocalizedString("Selected - Filter Read Articles", comment: "Selected - Filter Read Articles")
		} else {
			filterButton?.image = AppAssets.filterInactiveImage
			filterButton?.accLabelText = NSLocalizedString("Filter Read Articles", comment: "Filter Read Articles")
		}

		tableView.selectRow(at: nil, animated: false, scrollPosition: .top)

		if resetScroll {
			let snapshot = dataSource.snapshot()
			if snapshot.sectionIdentifiers.count > 0 && snapshot.itemIdentifiers(inSection: 0).count > 0 {
				tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
			}
		}
		
		updateToolbar()
	}
	
	func updateToolbar() {
		guard firstUnreadButton != nil else { return }
		
		markAllAsReadButton.isEnabled = coordinator.isTimelineUnreadAvailable
		firstUnreadButton.isEnabled = coordinator.isTimelineUnreadAvailable
		
		if coordinator.isRootSplitCollapsed {
			if let toolbarItems = toolbarItems, toolbarItems.last != firstUnreadButton {
				var items = toolbarItems
				items.append(firstUnreadButton)
				setToolbarItems(items, animated: false)
			}
		} else {
			if let toolbarItems = toolbarItems, toolbarItems.last == firstUnreadButton {
				let items = Array(toolbarItems[0..<toolbarItems.count - 1])
				setToolbarItems(items, animated: false)
			}
		}
	}
	
	func updateTitleUnreadCount() {
		if let titleView = navigationItem.titleView as? MasterTimelineTitleView {
			titleView.unreadCountView.unreadCount = coordinator.unreadCount
		}
	}
	
	func applyChanges(animated: Bool, completion: (() -> Void)? = nil) {
		if coordinator.articles.count == 0 {
			tableView.rowHeight = tableView.estimatedRowHeight
		} else {
			tableView.rowHeight = UITableView.automaticDimension
		}
		
        var snapshot = NSDiffableDataSourceSnapshot<Int, Article>()
		snapshot.appendSections([0])
		snapshot.appendItems(coordinator.articles, toSection: 0)

		dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
			self?.restoreSelectionIfNecessary(adjustScroll: false)
			completion?()
		}
	}
	
	func makeDataSource() -> UITableViewDiffableDataSource<Int, Article> {
		let dataSource: UITableViewDiffableDataSource<Int, Article> =
			MasterTimelineDataSource(tableView: tableView, cellProvider: { [weak self] tableView, indexPath, article in
				let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterTimelineTableViewCell
				self?.configure(cell, article: article)
				return cell
			})
		dataSource.defaultRowAnimation = .middle
		return dataSource
    }
	
	func configure(_ cell: MasterTimelineTableViewCell, article: Article) {
		
		let iconImage = iconImageFor(article)
		let featuredImage = featuredImageFor(article)
		
		let showFeedNames = coordinator.showFeedNames
		let showIcon = coordinator.showIcons && iconImage != nil
		cell.cellData = MasterTimelineCellData(article: article, showFeedName: showFeedNames, feedName: article.webFeed?.nameForDisplay, byline: article.byline(), iconImage: iconImage, showIcon: showIcon, featuredImage: featuredImage, numberOfLines: numberOfTextLines, iconSize: iconSize)
		
	}
	
	func iconImageFor(_ article: Article) -> IconImage? {
		if !coordinator.showIcons {
			return nil
		}
		return article.iconImage()
	}
	
	func featuredImageFor(_ article: Article) -> UIImage? {
		if let url = article.imageURL, let data = appDelegate.imageDownloader.image(for: url) {
			return RSImage(data: data)
		}
		return nil
	}
	
	func toggleArticleReadStatusAction(_ article: Article) -> UIAction? {
		guard !article.status.read || article.isAvailableToMarkUnread else { return nil }
		
		let title = article.status.read ?
			NSLocalizedString("Mark as Unread", comment: "Mark as Unread") :
			NSLocalizedString("Mark as Read", comment: "Mark as Read")
		let image = article.status.read ? AppAssets.circleClosedImage : AppAssets.circleOpenImage

		let action = UIAction(title: title, image: image) { [weak self] action in
			self?.coordinator.toggleRead(article)
		}
		
		return action
	}
	
	func toggleArticleStarStatusAction(_ article: Article) -> UIAction {

		let title = article.status.starred ?
			NSLocalizedString("Mark as Unstarred", comment: "Mark as Unstarred") :
			NSLocalizedString("Mark as Starred", comment: "Mark as Starred")
		let image = article.status.starred ? AppAssets.starOpenImage : AppAssets.starClosedImage

		let action = UIAction(title: title, image: image) { [weak self] action in
			self?.coordinator.toggleStar(article)
		}
		
		return action
	}

	func markAboveAsReadAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
		guard coordinator.canMarkAboveAsRead(for: article), let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else {
			return nil
		}

		let title = NSLocalizedString("Mark Above as Read", comment: "Mark Above as Read")
		let image = AppAssets.markAboveAsReadImage
		let action = UIAction(title: title, image: image) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				self?.coordinator.markAboveAsRead(article)
			}
		}
		return action
	}
	
	func markBelowAsReadAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
		guard coordinator.canMarkBelowAsRead(for: article), let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else {
			return nil
		}

		let title = NSLocalizedString("Mark Below as Read", comment: "Mark Below as Read")
		let image = AppAssets.markBelowAsReadImage
		let action = UIAction(title: title, image: image) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				self?.coordinator.markBelowAsRead(article)
			}
		}
		return action
	}
	
	func markAboveAsReadAlertAction(_ article: Article, indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard coordinator.canMarkAboveAsRead(for: article), let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else {
			return nil
		}

		let title = NSLocalizedString("Mark Above as Read", comment: "Mark Above as Read")
		let cancel = {
			completion(true)
		}

		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView, cancelCompletion: cancel) { [weak self] in
				self?.coordinator.markAboveAsRead(article)
				completion(true)
			}
		}
		return action
	}

	func markBelowAsReadAlertAction(_ article: Article, indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard coordinator.canMarkBelowAsRead(for: article), let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else {
			return nil
		}

		let title = NSLocalizedString("Mark Below as Read", comment: "Mark Below as Read")
		let cancel = {
			completion(true)
		}
		
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView, cancelCompletion: cancel) { [weak self] in
				self?.coordinator.markBelowAsRead(article)
				completion(true)
			}
		}
		return action
	}
	
	func discloseFeedAction(_ article: Article) -> UIAction? {
		guard let webFeed = article.webFeed,
			!coordinator.timelineFeedIsEqualTo(webFeed) else { return nil }
		
		let title = NSLocalizedString("Go to Feed", comment: "Go to Feed")
		let action = UIAction(title: title, image: AppAssets.openInSidebarImage) { [weak self] action in
			self?.coordinator.discloseWebFeed(webFeed, animations: [.scroll, .navigation])
		}
		return action
	}
	
	func discloseFeedAlertAction(_ article: Article, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let webFeed = article.webFeed,
			!coordinator.timelineFeedIsEqualTo(webFeed) else { return nil }

		let title = NSLocalizedString("Go to Feed", comment: "Go to Feed")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.discloseWebFeed(webFeed, animations: [.scroll, .navigation])
			completion(true)
		}
		return action
	}
	
	func markAllInFeedAsReadAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
		guard let webFeed = article.webFeed else { return nil }
		guard let fetchedArticles = try? webFeed.fetchArticles() else {
			return nil
		}

		let articles = Array(fetchedArticles)
		guard articles.canMarkAllAsRead(), let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else {
			return nil
		}
		
		
		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, webFeed.nameForDisplay) as String
		
		let action = UIAction(title: title, image: AppAssets.markAllAsReadImage) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				self?.coordinator.markAllAsRead(articles)
			}
		}
		return action
	}

	func markAllInFeedAsReadAlertAction(_ article: Article, indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let webFeed = article.webFeed else { return nil }
		guard let fetchedArticles = try? webFeed.fetchArticles() else {
			return nil
		}
		
		let articles = Array(fetchedArticles)
		guard articles.canMarkAllAsRead(), let contentView = self.tableView.cellForRow(at: indexPath)?.contentView else {
			return nil
		}
		
		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Mark All as Read in Feed")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, webFeed.nameForDisplay) as String
		let cancel = {
			completion(true)
		}
		
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView, cancelCompletion: cancel) { [weak self] in
				self?.coordinator.markAllAsRead(articles)
				completion(true)
			}
		}
		return action
	}
	
	func copyArticleURLAction(_ article: Article) -> UIAction? {
		guard let preferredLink = article.preferredLink, let url = URL(string: preferredLink) else { return nil }
		let title = NSLocalizedString("Copy Article URL", comment: "Copy Article URL")
		let action = UIAction(title: title, image: AppAssets.copyImage) { action in
			UIPasteboard.general.url = url
		}
		return action
	}
	
	func copyExternalURLAction(_ article: Article) -> UIAction? {
		guard let externalURL = article.externalURL, externalURL != article.preferredLink, let url = URL(string: externalURL) else { return nil }
		let title = NSLocalizedString("Copy External URL", comment: "Copy External URL")
		let action = UIAction(title: title, image: AppAssets.copyImage) { action in
			UIPasteboard.general.url = url
		}
		return action
	}


	func openInBrowserAction(_ article: Article) -> UIAction? {
		guard let preferredLink = article.preferredLink, let _ = URL(string: preferredLink) else {
			return nil
		}
		let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
		let action = UIAction(title: title, image: AppAssets.safariImage) { [weak self] action in
			self?.coordinator.showBrowserForArticle(article)
		}
		return action
	}

	func openInBrowserAlertAction(_ article: Article, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let preferredLink = article.preferredLink, let _ = URL(string: preferredLink) else {
			return nil
		}
		let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			self?.coordinator.showBrowserForArticle(article)
			completion(true)
		}
		return action
	}
	
	func shareDialogForTableCell(indexPath: IndexPath, url: URL, title: String?) {
		let activityViewController = UIActivityViewController(url: url, title: title, applicationActivities: nil)
		
		guard let cell = tableView.cellForRow(at: indexPath) else { return }
		let popoverController = activityViewController.popoverPresentationController
		popoverController?.sourceView = cell
		popoverController?.sourceRect = CGRect(x: 0, y: 0, width: cell.frame.size.width, height: cell.frame.size.height)
		
		present(activityViewController, animated: true)
	}
	
	func shareAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
		guard let preferredLink = article.preferredLink, let url = URL(string: preferredLink) else {
			return nil
		}
				
		let title = NSLocalizedString("Share", comment: "Share")
		let action = UIAction(title: title, image: AppAssets.shareImage) { [weak self] action in
			self?.shareDialogForTableCell(indexPath: indexPath, url: url, title: article.title)
		}
		return action
	}
	
	func shareAlertAction(_ article: Article, indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let preferredLink = article.preferredLink, let url = URL(string: preferredLink) else {
			return nil
		}
		
		let title = NSLocalizedString("Share", comment: "Share")
		let action = UIAlertAction(title: title, style: .default) { [weak self] action in
			completion(true)
			self?.shareDialogForTableCell(indexPath: indexPath, url: url, title: article.title)
		}
		return action
	}
	
}
