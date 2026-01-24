//
//  MainTimelineCollectionViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 24/01/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import os
import WebKit
import RSCore
import RSWeb
import Account
import Articles

let standardCellIdentifier = "MainTimelineCellStandard"
let standardCellIdentifierIndex0 = "MainTimelineCellIndexZero"
let standardCellIdentifierIcon = "MainTimelineCellIcon"
let standardCellIdentifierIconIndex0 = "MainTimelineCellIconIndexZero"


final class MainTimelineCollectionViewController: UICollectionViewController, UndoableCommandRunner {

	// MARK: Private Variables
	private var numberOfTextLines = 0
	private var iconSize = IconSize.medium
	private var refreshProgressView: RefreshProgressView?
	private lazy var feedTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(showFeedInspector(_:)))
	private lazy var filterButton = UIBarButtonItem(image: Assets.Images.filter, style: .plain, target: self, action: #selector(toggleFilter(_:)))
	private lazy var firstUnreadButton = UIBarButtonItem(image: Assets.Images.nextUnread, style: .plain, target: self, action: #selector(firstUnread(_:)))
	private lazy var dataSource = makeDataSource()
	
	private var timelineFeed: SidebarItem? {
		assert(coordinator != nil)
		return coordinator?.timelineFeed
	}

	private var showIcons: Bool {
		assert(coordinator != nil)
		return coordinator?.showIcons ?? false
	}

	private var currentArticle: Article? {
		assert(coordinator != nil)
		return coordinator?.currentArticle
	}

	private var timelineMiddleIndexPath: IndexPath? {
		get {
			coordinator?.timelineMiddleIndexPath
		}
		set {
			coordinator?.timelineMiddleIndexPath = newValue
		}
	}

	private var isTimelineViewControllerPending: Bool {
		get {
			coordinator?.isTimelineViewControllerPending ?? false
		}
		set {
			coordinator?.isTimelineViewControllerPending = newValue
		}
	}

	private var timelineIconImage: IconImage? {
		assert(coordinator != nil)
		return coordinator?.timelineIconImage
	}

	private var timelineDefaultReadFilterType: ReadFilterType {
		return timelineFeed?.defaultReadFilterType ?? .none
	}

	private var isReadArticlesFiltered: Bool {
		assert(coordinator != nil)
		return coordinator?.isReadArticlesFiltered ?? false
	}

	private var isTimelineUnreadAvailable: Bool {
		assert(coordinator != nil)
		return coordinator?.isTimelineUnreadAvailable ?? false
	}

	private var isRootSplitCollapsed: Bool {
		assert(coordinator != nil)
		return coordinator?.isRootSplitCollapsed ?? false
	}

	private var articles: ArticleArray? {
		assert(coordinator != nil)
		return coordinator?.articles
	}
	
	private lazy var navigationBarTitleLabel: UILabel = {
		let label = UILabel()
		label.font = UIFont.preferredFont(forTextStyle: .subheadline).bold()
		label.isUserInteractionEnabled = true
		label.numberOfLines = 1
		label.textAlignment = .center
		label.adjustsFontForContentSizeCategory = false
		let tap = UITapGestureRecognizer(target: self, action: #selector(showFeedInspector(_:)))
		label.addGestureRecognizer(tap)
		let pointerInteraction = UIPointerInteraction(delegate: nil)
		label.addInteraction(pointerInteraction)
		return label
	}()

	private lazy var navigationBarSubtitleTitleLabel: UILabel = {
		let label = UILabel()
		label.font = UIFont(name: "Helvetica", size: 12)
		label.textColor = .systemGray
		label.textAlignment = .center
		label.isUserInteractionEnabled = true
		label.adjustsFontForContentSizeCategory = false
		let tap = UITapGestureRecognizer(target: self, action: #selector(showFeedInspector(_:)))
		label.addGestureRecognizer(tap)
		return label
	}()

	
	// MARK: Variables
	weak var coordinator: SceneCoordinator?
	var undoableCommands = [UndoableCommand]()
	override var keyCommands: [UIKeyCommand]? {
		// If the first responder is the WKWebView (PreloadedWebView) we don't want to supply any keyboard
		// commands that the system is looking for by going up the responder chain. They will interfere with
		// the WKWebViews built in hardware keyboard shortcuts, specifically the up and down arrow keys.
		guard let current = UIResponder.currentFirstResponder, !(current is PreloadedWebView) else { return nil }

		return keyboardManager.keyCommands
	}
	override var canBecomeFirstResponder: Bool {
		true
	}
	
	// MARK: Private Constants
	private let searchController = UISearchController(searchResultsController: nil)
	private let keyboardManager = KeyboardManager(type: .timeline)
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MainTimelineCollectionViewController")
	
	// MARK: Constantns
	let scrollPositionQueue = CoalescingQueue(name: "Timeline Scroll Position", interval: 0.3, maxInterval: 1.0)
	
	
	// MARK: - IBOutlets
	@IBOutlet var markAllAsReadButton: UIBarButtonItem?
	
	// MARK: - Lifecycle
	
    override func viewDidLoad() {
		Self.logger.debug("MainTimelineCollectionViewController: viewDidLoad")
		assert(coordinator != nil)
		
        super.viewDidLoad()
		
		addNotificationObservers()
		configureCollectionView()
		configureSearchController()
		definesPresentationContext = true

        // Uncomment the following line to preserve selection between presentations
        self.clearsSelectionOnViewWillAppear = false
		
		numberOfTextLines = AppDefaults.shared.timelineNumberOfLines
		iconSize = AppDefaults.shared.timelineIconSize

		collectionView.refreshControl = UIRefreshControl()
		collectionView.refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)

		configureToolbar()
		resetUI(resetScroll: true)

		// Load the table and then scroll to the saved position if available
		applyChanges(animated: false) {
			if let restoreIndexPath = self.timelineMiddleIndexPath {
				self.collectionView.scrollToItem(at: restoreIndexPath, at: .centeredVertically, animated: false)
			}
		}

		// Disable swipe back on iPad Mice
		guard let gesture = self.navigationController?.interactivePopGestureRecognizer as? UIPanGestureRecognizer else {
			return
		}
		gesture.allowedScrollTypesMask = []

		navigationItem.title = nil // Don’t let "Timeline" accidentally show
		navigationItem.largeTitleDisplayMode = .never
		navigationItem.titleView = navigationBarTitleLabel
		navigationItem.subtitleView = navigationBarSubtitleTitleLabel
		
		
    }
	
	override func viewWillAppear(_ animated: Bool) {
		Self.logger.debug("MainTimelineViewController: viewWillAppear")

		super.viewWillAppear(animated)
		self.navigationController?.isToolbarHidden = false

		// If the nav bar is hidden, fade it in to avoid it showing stuff as it is getting laid out
		if navigationController?.navigationBar.isHidden ?? false {
			navigationController?.navigationBar.alpha = 0
		}

		updateNavigationBarTitle(coordinator?.timelineFeed?.nameForDisplay ?? "")
		coordinator?.updateNavigationBarSubtitles(nil)
	}

	override func viewDidAppear(_ animated: Bool) {
		Self.logger.debug("MainTimelineViewController: viewDidAppear")

		super.viewDidAppear(true)
		isTimelineViewControllerPending = false
		if navigationController?.navigationBar.alpha == 0 {
			UIView.animate(withDuration: 0.5) {
				self.navigationController?.navigationBar.alpha = 1
			}
		}
		if traitCollection.userInterfaceIdiom == .phone {
			if coordinator?.currentArticle != nil {
				if let indexPath = collectionView.indexPathsForSelectedItems?.first {
					collectionView.deselectItem(at: indexPath, animated: true)
				}
				coordinator?.selectArticle(nil)
			}
		}
	}

	func restoreSelectionIfNecessary(adjustScroll: Bool) {
		if let article = currentArticle, let indexPath = dataSource.indexPath(for: article) {
			if adjustScroll {
				collectionView.selectItemAndScrollIfNotVisible(at: indexPath, animations: [])
			} else {
				collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
			}
		}
	}

	func updateNavigationBarTitle(_ text: String) {
		navigationItem.title = text
		if let label = navigationItem.titleView as? UILabel {
			label.text = text
			label.isUserInteractionEnabled = ((coordinator?.timelineFeed as? PseudoFeed) == nil)
			label.sizeToFit()
		}
	}

	func updateNavigationBarSubtitle(_ text: String) {
		if let label = navigationItem.subtitleView as? UILabel {
			label.text = text
			label.isUserInteractionEnabled = ((coordinator?.timelineFeed as? PseudoFeed) == nil)
			label.sizeToFit()
		}
	}

	func reinitializeArticles(resetScroll: Bool) {
		Self.logger.debug("MainTimelineViewController: reinitializeArticles")
		resetUI(resetScroll: resetScroll)
	}

	func reloadArticles(animated: Bool) {
		Self.logger.debug("MainTimelineViewController: reloadArticles")
		applyChanges(animated: animated)
	}

	func updateArticleSelection(animations: Animations) {
		Self.logger.debug("MainTimelineViewController: updateArticleSelection")

		if let article = currentArticle, let indexPath = dataSource.indexPath(for: article) {
			collectionView.selectItemAndScrollIfNotVisible(at: indexPath, animations: animations)
		} else {
			collectionView.selectItem(at: nil, animated: animations.contains(.select), scrollPosition: .centeredVertically)
		}

		updateUI()
	}

	func updateUI() {
		Self.logger.debug("MainTimelineViewController: updateUI")

		refreshProgressView?.update()
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
		Self.logger.debug("MainTimelineViewController: focus")
		becomeFirstResponder()
	}
	
	// MARK: - Reloading

	func queueReloadAvailableCells() {
		CoalescingQueue.standard.add(self, #selector(reloadVisibleCells))
	}

	@objc private func reloadVisibleCells() {
		guard isViewLoaded, view.window != nil else {
			return
		}
		let indexPaths = collectionView.indexPathsForVisibleItems

		let visibleArticles = indexPaths.compactMap { dataSource.itemIdentifier(for: $0) }
		reloadCells(visibleArticles)
	}

	private func reloadCells(_ articles: [Article]) {
		guard !articles.isEmpty else {
			return
		}

		var snapshot = dataSource.snapshot()
		snapshot.reloadItems(articles)
		dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
			self?.restoreSelectionIfNecessary(adjustScroll: false)
		}
	}
	
	@objc func refreshAccounts(_ sender: Any) {
		collectionView.refreshControl?.endRefreshing()

		// This is a hack to make sure that an error dialog doesn't interfere with dismissing the refreshControl.
		// If the error dialog appears too closely to the call to endRefreshing, then the refreshControl never disappears.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			appDelegate.manualRefresh(errorHandler: ErrorHandler.present(self))
		}
	}
	
	// MARK: - Keyboard shortcuts

	@objc func selectNextUp(_ sender: Any?) {
		assert(coordinator != nil)
		coordinator?.selectPrevArticle()
	}

	@objc func selectNextDown(_ sender: Any?) {
		assert(coordinator != nil)
		coordinator?.selectNextArticle()
	}

	@objc func navigateToSidebar(_ sender: Any?) {
		assert(coordinator != nil)
		coordinator?.navigateToFeeds()
	}

	@objc func navigateToDetail(_ sender: Any?) {
		assert(coordinator != nil)
		coordinator?.navigateToDetail()
	}

	@objc func showFeedInspector(_ sender: Any?) {
		assert(coordinator != nil)
		coordinator?.showFeedInspector()
	}
	
	// MARK: - IBActions

	@objc func openInBrowser(_ sender: Any?) {
		assert(coordinator != nil)
		coordinator?.showBrowserForCurrentArticle()
	}

	@objc func openInAppBrowser(_ sender: Any?) {
		assert(coordinator != nil)
		coordinator?.showInAppBrowser()
	}

	@IBAction func toggleFilter(_ sender: Any) {
		assert(coordinator != nil)
		coordinator?.toggleReadArticlesFilter()
	}

	private func markAllAsReadInTimeline() {
		assert(coordinator != nil)
		coordinator?.markAllAsReadInTimeline()
	}

	@IBAction func markAllAsRead(_ sender: Any?) {
		let title = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")

		if let source = sender as? UIBarButtonItem {
			MarkAsReadAlertController.confirm(self, coordinator: coordinator, confirmTitle: title, sourceType: source) { [weak self] in
				self?.markAllAsReadInTimeline()
			}
		}

		if sender is UIKeyCommand {
			guard let indexPath = collectionView.indexPathsForSelectedItems?.first, let contentView = collectionView.cellForItem(at: indexPath)?.contentView else {
				return
			}

			MarkAsReadAlertController.confirm(self, coordinator: coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				self?.markAllAsReadInTimeline()
			}
		}
	}

	@IBAction func firstUnread(_ sender: Any) {
		assert(coordinator != nil)
		coordinator?.selectFirstUnread()
	}

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource

	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		becomeFirstResponder()
		let article = dataSource.itemIdentifier(for: indexPath)
		coordinator?.selectArticle(article, animations: [.scroll, .select, .navigation])
	}

    // MARK: UICollectionViewDelegate
	
	override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
		guard let firstIndex = indexPaths.first, let article = dataSource.itemIdentifier(for: firstIndex) else { return nil }

		return UIContextMenuConfiguration(identifier: firstIndex.row as NSCopying, previewProvider: nil, actionProvider: { [weak self] _ in

			guard let self = self else { return nil }

			var menuElements = [UIMenuElement]()

			var markActions = [UIAction]()
			if let action = self.toggleArticleReadStatusAction(article) {
				markActions.append(action)
			}
			markActions.append(self.toggleArticleStarStatusAction(article))
			if let action = self.markAboveAsReadAction(article, indexPath: firstIndex) {
				markActions.append(action)
			}
			if let action = self.markBelowAsReadAction(article, indexPath: firstIndex) {
				markActions.append(action)
			}
			menuElements.append(UIMenu(title: "", options: .displayInline, children: markActions))

			var secondaryActions = [UIAction]()
			if let action = self.discloseFeedAction(article) {
				secondaryActions.append(action)
			}
			if let action = self.markAllInFeedAsReadAction(article, indexPath: firstIndex) {
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

			if let action = self.shareAction(article, indexPath: firstIndex) {
				menuElements.append(UIMenu(title: "", options: .displayInline, children: [action]))
			}

			return UIMenu(title: "", children: menuElements)

		})
	}
	
	override func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, highlightPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
		guard let row = configuration.identifier as? Int,
			let cell = collectionView.cellForItem(at: IndexPath(row: row, section: 0)) else {
				return nil
		}

		let previewView = cell.contentView
		let parameters = UIPreviewParameters()
		parameters.backgroundColor = .white
		parameters.visiblePath = UIBezierPath(roundedRect: previewView.bounds,
											  cornerRadius: 20)
		return UITargetedPreview(view: cell, parameters: parameters)
	}
	
	
	override func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, dismissalPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
		guard let row = configuration.identifier as? Int,
			  let cell = collectionView.cellForItem(at: IndexPath(row: row, section: 0)), let _ = view.window else {
				return nil
		}

		let previewView = cell.contentView
		let parameters = UIPreviewParameters()
		parameters.backgroundColor = .white
		parameters.visiblePath = UIBezierPath(roundedRect: previewView.bounds,
											  cornerRadius: 20)
		return UITargetedPreview(view: cell, parameters: parameters)
	}
	
	
	
    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}


// MARK: Private API
private extension MainTimelineCollectionViewController {
	
	func addNotificationObservers() {
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .feedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)

		// TODO: fix this temporary hack, which will probably require refactoring image handling.
		// We want to know when to possibly reconfigure our cells with a new image, and we don’t
		// always know when an image is available — but watching the .htmlMetadataAvailable Notification
		// lets us know that it’s time to request an image.
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .htmlMetadataAvailable, object: nil)

		NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
			Task { @MainActor in
				self?.userDefaultsDidChange()
			}
		}
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
	}
	
	private func configureSearchController() {
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
		searchController.searchBar.barTintColor = .clear
		searchController.searchBar.scopeBarBackgroundImage = UIImage()
		searchController.searchBar.autocapitalizationType = .none
		navigationItem.searchController = searchController
		
		if traitCollection.userInterfaceIdiom == .pad {
			searchController.searchBar.selectedScopeButtonIndex = 1
			navigationItem.searchBarPlacementAllowsExternalIntegration = true
		}
	}
	
	private func configureCollectionView() {
		var config = UICollectionLayoutListConfiguration(appearance: .plain)
		config.showsSeparators = false
		config.headerMode = .none
		config.trailingSwipeActionsConfigurationProvider = { [unowned self] indexPath in
			guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }
			var actions = [UIContextualAction]()
			
			// Set up the star action
			let starTitle = article.status.starred ?
				NSLocalizedString("Unstar", comment: "Unstar") :
				NSLocalizedString("Star", comment: "Star")

			let starAction = UIContextualAction(style: .normal, title: starTitle) { [weak self] _, _, completion in
				self?.toggleStar(article)
				completion(true)
			}

			starAction.image = article.status.starred ? Assets.Images.starOpen : Assets.Images.starClosed
			starAction.backgroundColor = Assets.Colors.star

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

			moreAction.image = Assets.Images.more
			moreAction.backgroundColor = UIColor.systemGray
			
			actions.append(starAction)
			actions.append(moreAction)

			let config = UISwipeActionsConfiguration(actions: actions)
			config.performsFirstActionWithFullSwipe = false

			return config
		}
		config.leadingSwipeActionsConfigurationProvider = { [unowned self] indexPath in
			Self.logger.debug("Leading swipe provider called for \(indexPath.row)")
			guard let article = dataSource.itemIdentifier(for: indexPath) else { return nil }
			guard !article.status.read || article.isAvailableToMarkUnread else { return nil }
			var actions = [UIContextualAction]()
			
			// Set up the read action
			let readTitle = article.status.read ?
				NSLocalizedString("Mark as Unread", comment: "Mark as Unread") :
				NSLocalizedString("Mark as Read", comment: "Mark as Read")

			let readAction = UIContextualAction(style: .normal, title: readTitle) { [weak self] _, _, completion in
				self?.toggleRead(article)
				completion(true)
			}

			readAction.image = article.status.read ? Assets.Images.circleClosed : Assets.Images.circleOpen
			readAction.backgroundColor = Assets.Colors.primaryAccent
			actions.append(readAction)
			
			let config = UISwipeActionsConfiguration(actions: actions)
			config.performsFirstActionWithFullSwipe = false
			return config
		}
		
		collectionView.refreshControl = UIRefreshControl()
		collectionView.refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		collectionView.contentInsetAdjustmentBehavior = .always
		
		let layout = UICollectionViewCompositionalLayout.list(using: config)
		layout.configuration.contentInsetsReference = .safeArea
        collectionView.collectionViewLayout = layout
	}
	
	private func makeDataSource() -> UICollectionViewDiffableDataSource<Int, Article> {
		let dataSource: UICollectionViewDiffableDataSource<Int, Article> =
			MainTimelineCollectionViewDataSource(collectionView: collectionView, cellProvider: { [weak self] collectionView, indexPath, article in
				let cellData = self!.configure(article: article)
				if self!.showIcons {
					if indexPath.row == 0 {
						let cell = collectionView.dequeueReusableCell(withReuseIdentifier: standardCellIdentifierIconIndex0, for: indexPath) as! MainTimelineCollectionViewCell
						cell.cellData = cellData
						return cell
					} else {
						let cell = collectionView.dequeueReusableCell(withReuseIdentifier: standardCellIdentifierIcon, for: indexPath) as! MainTimelineCollectionViewCell
						cell.cellData = cellData
						return cell
					}
				} else {
					if indexPath.row == 0 {
						let cell = collectionView.dequeueReusableCell(withReuseIdentifier: standardCellIdentifierIndex0, for: indexPath) as! MainTimelineCollectionViewCell
						cell.cellData = cellData
						return cell
					} else {
						let cell = collectionView.dequeueReusableCell(withReuseIdentifier: standardCellIdentifier, for: indexPath) as! MainTimelineCollectionViewCell  
						cell.cellData = cellData
						return cell
					}
				}
			})
		
		return dataSource
	}
	
	@discardableResult
	private func configure(article: Article) -> MainTimelineCellData {
		let iconImage = iconImageFor(article)
		let showFeedNames = coordinator?.showFeedNames ?? ShowFeedName.none
		let showIcon = showIcons && iconImage != nil
		let cellData = MainTimelineCellData(article: article, showFeedName: showFeedNames, feedName: article.feed?.nameForDisplay, byline: article.byline(), iconImage: iconImage, showIcon: showIcon, numberOfLines: numberOfTextLines, iconSize: iconSize)
		return cellData
	}
	
	private func iconImageFor(_ article: Article) -> IconImage? {
		if !showIcons {
			return nil
		}
		return article.iconImage()
	}
	
	func searchArticles(_ searchString: String, _ searchScope: SearchScope) {
		assert(coordinator != nil)
		coordinator?.searchArticles(searchString, searchScope)
	}

	func configureToolbar() {
		if traitCollection.userInterfaceIdiom == .phone {
			toolbarItems?.insert(.flexibleSpace(), at: 1)
			toolbarItems?.insert(navigationItem.searchBarPlacementBarButtonItem, at: 2)
		}
	}

	func resetUI(resetScroll: Bool) {
		let shouldShowFilterButton = coordinator?.shouldShowFilterButton() ?? false
		navigationItem.rightBarButtonItem = shouldShowFilterButton ? filterButton : nil

		if isReadArticlesFiltered {
			filterButton.style = .prominent
			filterButton.tintColor = Assets.Colors.primaryAccent
			filterButton.accLabelText = NSLocalizedString("Selected - Filter Read Articles", comment: "Selected - Filter Read Articles")
		} else {
			filterButton.style = .plain
			filterButton.tintColor = nil
			filterButton.accLabelText = NSLocalizedString("Filter Read Articles", comment: "Filter Read Articles")
		}

		collectionView.selectItem(at: nil, animated: false, scrollPosition: .top)

		if resetScroll {
			let snapshot = dataSource.snapshot()
			if snapshot.sectionIdentifiers.count > 0 && snapshot.itemIdentifiers(inSection: 0).count > 0 {
				//collectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .top)
			}
		}

		updateToolbar()
	}

	func updateToolbar() {
		markAllAsReadButton?.isEnabled = isTimelineUnreadAvailable
		firstUnreadButton.isEnabled = coordinator?.isAnyUnreadAvailable ?? false

		if isRootSplitCollapsed {
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

	func applyChanges(animated: Bool, completion: (() -> Void)? = nil) {
		var snapshot = NSDiffableDataSourceSnapshot<Int, Article>()
		snapshot.appendSections([0])
		snapshot.appendItems(articles ?? ArticleArray(), toSection: 0)

		dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
			self?.restoreSelectionIfNecessary(adjustScroll: false)
			completion?()
		}
	}
	
	

	

}



// MARK: - Notifications API
private extension MainTimelineCollectionViewController {
	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		Self.logger.debug("MainTimelineViewController: unreadCountDidChange")
		updateUI()
	}

	@objc func statusesDidChange(_ note: Notification) {
		Self.logger.debug("MainTimelineViewController: statusesDidChange")

		guard isViewLoaded, view.window != nil else {
			return
		}
		guard let articleIDs = note.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String>, !articleIDs.isEmpty else {
			return
		}
		let indexPaths = collectionView.indexPathsForVisibleItems
		if indexPaths.count == 0 {
			return
		}

		let visibleArticles = indexPaths.compactMap { dataSource.itemIdentifier(for: $0) }
		let visibleUpdatedArticles = visibleArticles.filter { articleIDs.contains($0.articleID) }
		reloadCells(visibleUpdatedArticles)
	}

	@objc func feedIconDidBecomeAvailable(_ note: Notification) {
		Self.logger.debug("MainTimelineViewController: feedIconDidBecomeAvailable")

		guard isViewLoaded, view.window != nil else {
			return
		}
		guard let feed = note.userInfo?[UserInfoKey.feed] as? Feed else {
			return
		}

		updateIconForVisibleArticles(feed)
	}

	@objc func avatarDidBecomeAvailable(_ note: Notification) {
		Self.logger.debug("MainTimelineViewController: avatarDidBecomeAvailable")

		guard isViewLoaded, view.window != nil else {
			return
		}
		guard showIcons, let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
			return
		}
		let indexPaths = collectionView.indexPathsForVisibleItems

		let articlesToReload = indexPaths.compactMap { indexPath -> Article? in
			guard let article = dataSource.itemIdentifier(for: indexPath),
				  let authors = article.authors,
				  !authors.isEmpty else {
				return nil
			}
			for author in authors {
				if author.avatarURL == avatarURL {
					return article
				}
			}
			return nil
		}
		reloadCells(articlesToReload)
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		Self.logger.debug("MainTimelineViewController: faviconDidBecomeAvailable")

		guard isViewLoaded, view.window != nil else {
			return
		}

		updateIconForVisibleArticles()
	}
	
	/// Update icon for all visible articles — or, if feed is non-nil, update articles only from that feed.
	private func updateIconForVisibleArticles(_ feed: Feed? = nil) {
		guard isViewLoaded, view.window != nil else {
			return
		}
		guard showIcons else {
			return
		}
		let indexPaths = collectionView.indexPathsForVisibleItems

		let articlesToReload = indexPaths.compactMap { indexPath -> Article? in
			guard let article = dataSource.itemIdentifier(for: indexPath) else {
				return nil
			}
			if feed == nil || feed == article.feed {
				return article
			}
			return nil
		}
		reloadCells(articlesToReload)
	}

	func userDefaultsDidChange() {
		Self.logger.debug("MainTimelineViewController: userDefaultsDidChange")

		if self.numberOfTextLines != AppDefaults.shared.timelineNumberOfLines || self.iconSize != AppDefaults.shared.timelineIconSize {
			self.numberOfTextLines = AppDefaults.shared.timelineNumberOfLines
			self.iconSize = AppDefaults.shared.timelineIconSize
			self.reloadVisibleCells()
		}
		self.updateToolbar()
	}

	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		Self.logger.debug("MainTimelineViewController: contentSizeCategoryDidChange")
		reloadVisibleCells()
	}

	@objc func displayNameDidChange(_ note: Notification) {
		Self.logger.debug("MainTimelineViewController: displayNameDidChange")
		updateNavigationBarTitle(timelineFeed?.nameForDisplay ?? "")
	}

	@objc func willEnterForeground(_ note: Notification) {
		Self.logger.debug("MainTimelineViewController: willEnterForeground")
		updateUI()
	}

	@objc func scrollPositionDidChange() {
		Self.logger.debug("MainTimelineViewController: scrollPositionDidChange")
		timelineMiddleIndexPath = collectionView.middleVisibleRow()
	}

}


extension MainTimelineCollectionViewController: UISearchControllerDelegate {

	func willPresentSearchController(_ searchController: UISearchController) {
		coordinator?.beginSearching()
		searchController.searchBar.showsScopeBar = true
	}

	func willDismissSearchController(_ searchController: UISearchController) {
		coordinator?.endSearching()
		searchController.searchBar.showsScopeBar = false
		updateToolbar()
	}

}

extension MainTimelineCollectionViewController: UISearchResultsUpdating {

	func updateSearchResults(for searchController: UISearchController) {
		let searchScope = SearchScope(rawValue: searchController.searchBar.selectedScopeButtonIndex)!
		searchArticles(searchController.searchBar.text!, searchScope)
	}

}

extension MainTimelineCollectionViewController: UISearchBarDelegate {
	func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
		let searchScope = SearchScope(rawValue: selectedScope)!
		searchArticles(searchBar.text!, searchScope)
	}
}

// MARK: Article Actions
extension MainTimelineCollectionViewController {
	func toggleRead(_ article: Article) {
		assert(coordinator != nil)
		coordinator?.toggleRead(article)
	}

	func toggleArticleReadStatusAction(_ article: Article) -> UIAction? {
		guard !article.status.read || article.isAvailableToMarkUnread else { return nil }

		let title = article.status.read ?
			NSLocalizedString("Mark as Unread", comment: "Mark as Unread") :
			NSLocalizedString("Mark as Read", comment: "Mark as Read")
		let image = article.status.read ? Assets.Images.circleClosed : Assets.Images.circleOpen

		let action = UIAction(title: title, image: image) { [weak self] _ in
			self?.toggleRead(article)
		}

		return action
	}

	func toggleStar(_ article: Article) {
		assert(coordinator != nil)
		coordinator?.toggleStar(article)
	}

	func toggleArticleStarStatusAction(_ article: Article) -> UIAction {

		let title = article.status.starred ?
			NSLocalizedString("Mark as Unstarred", comment: "Mark as Unstarred") :
			NSLocalizedString("Mark as Starred", comment: "Mark as Starred")
		let image = article.status.starred ? Assets.Images.starOpen : Assets.Images.starClosed

		let action = UIAction(title: title, image: image) { [weak self] _ in
			self?.toggleStar(article)
		}

		return action
	}

	func markAboveAsRead(_ article: Article) {
		assert(coordinator != nil)
		coordinator?.markAboveAsRead(article)
	}

	func canMarkAboveAsRead(for article: Article) -> Bool {
		assert(coordinator != nil)
		return coordinator?.canMarkAboveAsRead(for: article) ?? false
	}

	func markAboveAsReadAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
		guard canMarkAboveAsRead(for: article), let contentView = self.collectionView.cellForItem(at: indexPath)?.contentView else {
			return nil
		}

		let title = NSLocalizedString("Mark Above as Read", comment: "Mark Above as Read")
		let image = Assets.Images.markAboveAsRead
		let action = UIAction(title: title, image: image) { [weak self] _ in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				self?.markAboveAsRead(article)
			}
		}
		return action
	}

	func markBelowAsRead(_ article: Article) {
		assert(coordinator != nil)
		coordinator?.markBelowAsRead(article)
	}

	func canMarkBelowAsRead(for article: Article) -> Bool {
		assert(coordinator != nil)
		return coordinator?.canMarkBelowAsRead(for: article) ?? false
	}

	func markBelowAsReadAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
		guard canMarkBelowAsRead(for: article), let contentView = self.collectionView.cellForItem(at: indexPath)?.contentView else {
			return nil
		}

		let title = NSLocalizedString("Mark Below as Read", comment: "Mark Below as Read")
		let image = Assets.Images.markBelowAsRead
		let action = UIAction(title: title, image: image) { [weak self] _ in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				self?.markBelowAsRead(article)
			}
		}
		return action
	}

	func markAboveAsReadAlertAction(_ article: Article, indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard canMarkAboveAsRead(for: article), let contentView = self.collectionView.cellForItem(at: indexPath)?.contentView else {
			return nil
		}

		let title = NSLocalizedString("Mark Above as Read", comment: "Mark Above as Read")
		let cancel = {
			completion(true)
		}

		let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView, cancelCompletion: cancel) { [weak self] in
				self?.markAboveAsRead(article)
				completion(true)
			}
		}
		return action
	}

	func markBelowAsReadAlertAction(_ article: Article, indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard canMarkBelowAsRead(for: article), let contentView = self.collectionView.cellForItem(at: indexPath)?.contentView else {
			return nil
		}

		let title = NSLocalizedString("Mark Below as Read", comment: "Mark Below as Read")
		let cancel = {
			completion(true)
		}

		let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView, cancelCompletion: cancel) { [weak self] in
				self?.markBelowAsRead(article)
				completion(true)
			}
		}
		return action
	}

	func timelineFeedIsEqualTo(_ feed: Feed) -> Bool {
		assert(coordinator != nil)
		return coordinator?.timelineFeedIsEqualTo(feed) ?? false
	}

	func discloseFeed(_ feed: Feed, animations: Animations = []) {
		assert(coordinator != nil)
		coordinator?.discloseFeed(feed, animations: animations)
	}

	func discloseFeedAction(_ article: Article) -> UIAction? {
		guard let feed = article.feed,
			!timelineFeedIsEqualTo(feed) else { return nil }

		let title = NSLocalizedString("Go to Feed", comment: "Go to Feed")
		let action = UIAction(title: title, image: Assets.Images.openInSidebar) { [weak self] _ in
			self?.discloseFeed(feed, animations: [.scroll, .navigation])
		}
		return action
	}

	func discloseFeedAlertAction(_ article: Article, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let feed = article.feed,
			!timelineFeedIsEqualTo(feed) else { return nil }

		let title = NSLocalizedString("Go to Feed", comment: "Go to Feed")
		let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
			self?.discloseFeed(feed, animations: [.scroll, .navigation])
			completion(true)
		}
		return action
	}

	func markAllAsRead(_ articles: ArticleArray) {
		assert(coordinator != nil)
		coordinator?.markAllAsRead(articles)
	}

	func markAllInFeedAsReadAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
		guard let feed = article.feed else { return nil }
		guard let fetchedArticles = try? feed.fetchArticles() else {
			return nil
		}

		let articles = Array(fetchedArticles)
		guard articles.canMarkAllAsRead(), let contentView = self.collectionView.cellForItem(at: indexPath)?.contentView else {
			return nil
		}

		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String

		let action = UIAction(title: title, image: Assets.Images.markAllAsRead) { [weak self] _ in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView) { [weak self] in
				self?.markAllAsRead(articles)
			}
		}
		return action
	}

	func markAllInFeedAsReadAlertAction(_ article: Article, indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let feed = article.feed else { return nil }
		guard let fetchedArticles = try? feed.fetchArticles() else {
			return nil
		}

		let articles = Array(fetchedArticles)
		guard articles.canMarkAllAsRead(), let contentView = self.collectionView.cellForItem(at: indexPath)?.contentView else {
			return nil
		}

		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Mark All as Read in Feed")
		let title = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String
		let cancel = {
			completion(true)
		}

		let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
			MarkAsReadAlertController.confirm(self, coordinator: self?.coordinator, confirmTitle: title, sourceType: contentView, cancelCompletion: cancel) { [weak self] in
				self?.markAllAsRead(articles)
				completion(true)
			}
		}
		return action
	}

	func copyArticleURLAction(_ article: Article) -> UIAction? {
		guard let url = article.preferredURL else { return nil }
		let title = NSLocalizedString("Copy Article URL", comment: "Copy Article URL")
		let action = UIAction(title: title, image: Assets.Images.copy) { _ in
			UIPasteboard.general.url = url
		}
		return action
	}

	func copyExternalURLAction(_ article: Article) -> UIAction? {
		guard let externalLink = article.externalLink, externalLink != article.preferredLink, let url = URL(string: externalLink) else { return nil }
		let title = NSLocalizedString("Copy External URL", comment: "Copy External URL")
		let action = UIAction(title: title, image: Assets.Images.copy) { _ in
			UIPasteboard.general.url = url
		}
		return action
	}

	func showBrowserForArticle(_ article: Article) {
		assert(coordinator != nil)
		coordinator?.showBrowserForArticle(article)
	}

	func openInBrowserAction(_ article: Article) -> UIAction? {
		guard article.preferredURL != nil else {
			return nil
		}
		let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
		let action = UIAction(title: title, image: Assets.Images.safari) { [weak self] _ in
			self?.showBrowserForArticle(article)
		}
		return action
	}

	func openInBrowserAlertAction(_ article: Article, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard article.preferredURL != nil else {
			return nil
		}

		let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
		let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
			self?.showBrowserForArticle(article)
			completion(true)
		}
		return action
	}

	func shareDialogForTableCell(indexPath: IndexPath, url: URL, title: String?) {
		let activityViewController = UIActivityViewController(url: url, title: title, applicationActivities: nil)

		guard let cell = collectionView.cellForItem(at: indexPath) else {
			return
		}
		let popoverController = activityViewController.popoverPresentationController
		popoverController?.sourceView = cell
		popoverController?.sourceRect = CGRect(x: 0, y: 0, width: cell.frame.size.width, height: cell.frame.size.height)

		present(activityViewController, animated: true)
	}

	func shareAction(_ article: Article, indexPath: IndexPath) -> UIAction? {
		guard let url = article.preferredURL else { return nil }
		let title = NSLocalizedString("Share", comment: "Share")
		let action = UIAction(title: title, image: Assets.Images.share) { [weak self] _ in
			self?.shareDialogForTableCell(indexPath: indexPath, url: url, title: article.title)
		}
		return action
	}

	func shareAlertAction(_ article: Article, indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
		guard let url = article.preferredURL else { return nil }
		let title = NSLocalizedString("Share", comment: "Share")
		let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
			completion(true)
			self?.shareDialogForTableCell(indexPath: indexPath, url: url, title: article.title)
		}
		return action
	}
}

