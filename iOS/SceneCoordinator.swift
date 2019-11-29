//
//  NavigationModelController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import UserNotifications
import Account
import Articles
import RSCore
import RSTree

enum PanelMode {
	case unset
	case three
	case standard
}
enum SearchScope: Int {
	case timeline = 0
	case global = 1
}

class SceneCoordinator: NSObject, UndoableCommandRunner, UnreadCountProvider {
	
	var undoableCommands = [UndoableCommand]()
	var undoManager: UndoManager? {
		return rootSplitViewController.undoManager
	}
	
	private var panelMode: PanelMode = .unset
	
	private var activityManager = ActivityManager()
	
	private var isShowingExtractedArticle = false
	private var articleExtractor: ArticleExtractor? = nil

	private var rootSplitViewController: RootSplitViewController!
	private var masterNavigationController: UINavigationController!
	private var masterFeedViewController: MasterFeedViewController!
	private var masterTimelineViewController: MasterTimelineViewController?
	private var subSplitViewController: UISplitViewController?
	
	private var articleViewController: ArticleViewController? {
		if let detail = masterNavigationController.viewControllers.last as? ArticleViewController {
			return detail
		}
		if let subSplit = subSplitViewController {
			if let navController = subSplit.viewControllers.last as? UINavigationController {
				return navController.topViewController as? ArticleViewController
			}
		} else {
			if let navController = rootSplitViewController.viewControllers.last as? UINavigationController {
				return navController.topViewController as? ArticleViewController
			}
		}
		return nil
	}
	
	private var wasRootSplitViewControllerCollapsed = false
	
	private let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5)
	private var fetchSerialNumber = 0
	private let fetchRequestQueue = FetchRequestQueue()
	
	private var animatingChanges = false
	private var expandedTable = Set<ContainerIdentifier>()
	private var readFilterEnabledTable = [FeedIdentifier: Bool]()
	private var shadowTable = [[Node]]()
	private var lastSearchString = ""
	private var lastSearchScope: SearchScope? = nil
	private var isSearching: Bool = false
	private var savedSearchArticles: ArticleArray? = nil
	private var savedSearchArticleIds: Set<String>? = nil
	var isTimelineViewControllerPending = false
	var isArticleViewControllerPending = false
	
	private(set) var sortDirection = AppDefaults.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortParametersDidChange()
			}
		}
	}
	private(set) var groupByFeed = AppDefaults.timelineGroupByFeed {
		didSet {
			if groupByFeed != oldValue {
				sortParametersDidChange()
			}
		}
	}
	
	var prefersStatusBarHidden = false
	
	var displayUndoAvailableTip: Bool {
		get { AppDefaults.displayUndoAvailableTip }
		set { AppDefaults.displayUndoAvailableTip = newValue }
	}

	private let treeControllerDelegate = WebFeedTreeControllerDelegate()
	private let treeController: TreeController
	
	var stateRestorationActivity: NSUserActivity {
		let activity = activityManager.stateRestorationActivity
		var userInfo = activity.userInfo == nil ? [AnyHashable: Any]() : activity.userInfo
		userInfo![UserInfoKey.windowState] = windowState()
		activity.userInfo = userInfo
		return activity
	}
	
	var isRootSplitCollapsed: Bool {
		return rootSplitViewController.isCollapsed
	}
	
	var isThreePanelMode: Bool {
		return panelMode == .three
	}
	
	var isReadFeedsFiltered: Bool {
		return treeControllerDelegate.isReadFiltered
	}
	
	var isReadArticlesFiltered: Bool {
		if let feedID = timelineFeed?.feedID, let readFilterEnabled = readFilterEnabledTable[feedID] {
			return readFilterEnabled
		} else {
			return timelineDefaultReadFilterType != .none
		}
	}
	
	var timelineDefaultReadFilterType: ReadFilterType {
		return timelineFeed?.defaultReadFilterType ?? .none
	}
	
	var rootNode: Node {
		return treeController.rootNode
	}
	
	private(set) var currentFeedIndexPath: IndexPath?
	
	var timelineIconImage: IconImage? {
		if let feed = timelineFeed as? WebFeed {
			
			let feedIconImage = appDelegate.webFeedIconDownloader.icon(for: feed)
			if feedIconImage != nil {
				return feedIconImage
			}
			
			if let faviconIconImage = appDelegate.faviconDownloader.faviconAsIcon(for: feed) {
				return faviconIconImage
			}
			
		}
		
		return (timelineFeed as? SmallIconProvider)?.smallIcon
	}
	
	private var exceptionArticleFetcher: ArticleFetcher?
	private(set) var timelineFeed: Feed?
	
	var timelineMiddleIndexPath: IndexPath?
	
	private(set) var showFeedNames = false
	private(set) var showIcons = false

	var isPrevFeedAvailable: Bool {
		guard let indexPath = currentFeedIndexPath else {
			return false
		}
		return indexPath.section > 0 || indexPath.row > 0
	}
	
	var isNextFeedAvailable: Bool {
		guard let indexPath = currentFeedIndexPath else {
			return false
		}
		
		let nextIndexPath: IndexPath = {
			if indexPath.row + 1 >= shadowTable[indexPath.section].count {
				return IndexPath(row: 0, section: indexPath.section + 1)
			} else {
				return IndexPath(row: indexPath.row + 1, section: indexPath.section)
			}
		}()
		
		return nextIndexPath.section < shadowTable.count && nextIndexPath.row < shadowTable[nextIndexPath.section].count
	}

	var prevFeedIndexPath: IndexPath? {
		guard isPrevFeedAvailable, let indexPath = currentFeedIndexPath else {
			return nil
		}
		
		let prevIndexPath: IndexPath = {
			if indexPath.row - 1 < 0 {
				return IndexPath(row: shadowTable[indexPath.section - 1].count - 1, section: indexPath.section - 1)
			} else {
				return IndexPath(row: indexPath.row - 1, section: indexPath.section)
			}
		}()
		
		return prevIndexPath
	}
	
	var nextFeedIndexPath: IndexPath? {
		guard isNextFeedAvailable, let indexPath = currentFeedIndexPath else {
			return nil
		}
		
		let nextIndexPath: IndexPath = {
			if indexPath.row + 1 >= shadowTable[indexPath.section].count {
				return IndexPath(row: 0, section: indexPath.section + 1)
			} else {
				return IndexPath(row: indexPath.row + 1, section: indexPath.section)
			}
		}()
		
		return nextIndexPath
	}

	var isPrevArticleAvailable: Bool {
		guard let articleRow = currentArticleRow else {
			return false
		}
		return articleRow > 0
	}
	
	var isNextArticleAvailable: Bool {
		guard let articleRow = currentArticleRow else {
			return false
		}
		return articleRow + 1 < articles.count
	}
	
	var prevArticle: Article? {
		guard isPrevArticleAvailable, let articleRow = currentArticleRow else {
			return nil
		}
		return articles[articleRow - 1]
	}
	
	var nextArticle: Article? {
		guard isNextArticleAvailable, let articleRow = currentArticleRow else {
			return nil
		}
		return articles[articleRow + 1]
	}
	
	var firstUnreadArticleIndexPath: IndexPath? {
		for (row, article) in articles.enumerated() {
			if !article.status.read {
				return IndexPath(row: row, section: 0)
			}
		}
		return nil
	}
	
	var currentArticle: Article?

	private(set) var articles = ArticleArray()
	private var currentArticleRow: Int? {
		guard let article = currentArticle else { return nil }
		return articles.firstIndex(of: article)
	}

	var isTimelineUnreadAvailable: Bool {
		return timelineFeed?.unreadCount ?? 0 > 0
	}
	
	var isAnyUnreadAvailable: Bool {
		return appDelegate.unreadCount > 0
	}
	
	var unreadCount: Int = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}
	
	override init() {
		treeController = TreeController(delegate: treeControllerDelegate)

		super.init()
		
		for sectionNode in treeController.rootNode.childNodes {
			markExpanded(sectionNode)
			shadowTable.append([Node]())
		}
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidInitialize(_:)), name: .UnreadCountDidInitialize, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddAccount(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidDeleteAccount(_:)), name: .UserDidDeleteAccount, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
		
	}
	
	func start(for size: CGSize) -> UIViewController {
		rootSplitViewController = RootSplitViewController()
		rootSplitViewController.coordinator = self
		rootSplitViewController.preferredDisplayMode = .allVisible
		rootSplitViewController.viewControllers = [InteractiveNavigationController.template()]
		rootSplitViewController.delegate = self
		
		masterNavigationController = (rootSplitViewController.viewControllers.first as! UINavigationController)
		masterNavigationController.delegate = self
		
		masterFeedViewController = UIStoryboard.main.instantiateController(ofType: MasterFeedViewController.self)
		masterFeedViewController.coordinator = self
		masterNavigationController.pushViewController(masterFeedViewController, animated: false)
		
		let articleViewController = UIStoryboard.main.instantiateController(ofType: ArticleViewController.self)
		articleViewController.coordinator = self
		let detailNavigationController = addNavControllerIfNecessary(articleViewController, showButton: true)
		rootSplitViewController.showDetailViewController(detailNavigationController, sender: self)

		configurePanelMode(for: size)
		
		return rootSplitViewController
	}
	
	func restoreWindowState(_ activity: NSUserActivity?) {
		if let activity = activity, let windowState = activity.userInfo?[UserInfoKey.windowState] as? [AnyHashable: Any] {
			
			if let containerExpandedWindowState = windowState[UserInfoKey.containerExpandedWindowState] as? [[AnyHashable: AnyHashable]] {
				let containerIdentifers = containerExpandedWindowState.compactMap( { ContainerIdentifier(userInfo: $0) })
				expandedTable = Set(containerIdentifers)
			}
			
			if let readArticlesFilterState = windowState[UserInfoKey.readArticlesFilterState] as? [[AnyHashable: AnyHashable]: Bool] {
				for key in readArticlesFilterState.keys {
					if let feedIdentifier = FeedIdentifier(userInfo: key) {
						readFilterEnabledTable[feedIdentifier] = readArticlesFilterState[key]
					}
				}
			}

			rebuildBackingStores(initialLoad: true)

			// You can't assign the Feeds Read Filter until we've built the backing stores at least once or there is nothing
			// for state restoration to work with while we are waiting for the unread counts to initialize.
			if let readFeedsFilterState = windowState[UserInfoKey.readFeedsFilterState] as? Bool {
				treeControllerDelegate.isReadFiltered = readFeedsFilterState
			}
			
		} else {
			
			rebuildBackingStores(initialLoad: true)
			
		}
	}
	
	func handle(_ activity: NSUserActivity) {
		selectFeed(nil, animated: false) {
			guard let activityType = ActivityType(rawValue: activity.activityType) else { return }
			switch activityType {
			case .restoration:
				break
			case .selectFeed:
				self.handleSelectFeed(activity.userInfo)
			case .nextUnread:
				self.selectFirstUnreadInAllUnread()
			case .readArticle:
				self.handleReadArticle(activity.userInfo)
			case .addFeedIntent:
				self.showAdd(.feed)
			}
		}
	}
	
	func handle(_ response: UNNotificationResponse) {
		let userInfo = response.notification.request.content.userInfo
		handleReadArticle(userInfo)
	}
	
	func configurePanelMode(for size: CGSize) {
		guard rootSplitViewController.traitCollection.userInterfaceIdiom == .pad else {
			return
		}
		
		if (size.width / size.height) > 1.2 {
			if panelMode == .unset || panelMode == .standard {
				panelMode = .three
				configureThreePanelMode()
			}
		} else {
			if panelMode == .unset || panelMode == .three {
				panelMode = .standard
				configureStandardPanelMode()
			}
		}
		
		wasRootSplitViewControllerCollapsed = rootSplitViewController.isCollapsed
	}
	
	func selectFirstUnreadInAllUnread() {
		selectFeed(IndexPath(row: 1, section: 0), animated: false) {
			self.selectFirstUnreadArticleInTimeline()
		}
	}

	func showSearch() {
		selectFeed(nil, animated: false) {
			self.installTimelineControllerIfNecessary(animated: false)
			DispatchQueue.main.asyncAfter(deadline: .now()) {
				self.masterTimelineViewController!.showSearchAll()
			}
		}
	}
	
	// MARK: Notifications
	
	@objc func unreadCountDidInitialize(_ notification: Notification) {
		guard notification.object is AccountManager else {
			return
		}
		if isReadFeedsFiltered {
			rebuildBackingStores()
		}
		treeControllerDelegate.resetFilterExceptions()
	}

	@objc func statusesDidChange(_ note: Notification) {
		updateUnreadCount()
	}
	
	@objc func containerChildrenDidChange(_ note: Notification) {
		if timelineFetcherContainsAnyPseudoFeed() || timelineFetcherContainsAnyFolder() {
			refreshTimeline()
		}
		rebuildBackingStores()
	}
	
	@objc func batchUpdateDidPerform(_ notification: Notification) {
		rebuildBackingStores()
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		rebuildBackingStores()
	}

	@objc func accountStateDidChange(_ note: Notification) {
		let expandNewlyActivatedAccount = {
			if let account = note.userInfo?[Account.UserInfoKey.account] as? Account,
				account.isActive,
				let node = self.treeController.rootNode.childNodeRepresentingObject(account) {
					self.markExpanded(node)
			}
		}

		if timelineFetcherContainsAnyPseudoFeed() {
			fetchAndReplaceArticlesAsync(animated: true) {
				self.masterTimelineViewController?.reinitializeArticles()
				self.rebuildBackingStores() {
					expandNewlyActivatedAccount()
				}
			}
		} else {
			rebuildBackingStores() {
				expandNewlyActivatedAccount()
			}
		}
		
	}
	
	@objc func userDidAddAccount(_ note: Notification) {
		let expandNewAccount = {
			if let account = note.userInfo?[Account.UserInfoKey.account] as? Account,
				let node = self.treeController.rootNode.childNodeRepresentingObject(account) {
				self.markExpanded(node)
			}
		}
		
		if timelineFetcherContainsAnyPseudoFeed() {
			fetchAndReplaceArticlesAsync(animated: true) {
				self.masterTimelineViewController?.reinitializeArticles()
				self.rebuildBackingStores() {
					expandNewAccount()
				}
			}
		} else {
			rebuildBackingStores() {
				expandNewAccount()
			}
		}
	}

	@objc func userDidDeleteAccount(_ note: Notification) {
		let cleanupAccount = {
			if let account = note.userInfo?[Account.UserInfoKey.account] as? Account,
				let node = self.treeController.rootNode.childNodeRepresentingObject(account) {
				self.unmarkExpanded(node)
			}
		}
		
		if timelineFetcherContainsAnyPseudoFeed() {
			fetchAndReplaceArticlesAsync(animated: true) {
				self.masterTimelineViewController?.reinitializeArticles()
				self.rebuildBackingStores() {
					cleanupAccount()
				}
			}
		} else {
			rebuildBackingStores() {
				cleanupAccount()
			}
		}
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		self.sortDirection = AppDefaults.timelineSortDirection
		self.groupByFeed = AppDefaults.timelineGroupByFeed
	}
	
	@objc func accountDidDownloadArticles(_ note: Notification) {
		guard let feeds = note.userInfo?[Account.UserInfoKey.webFeeds] as? Set<WebFeed> else {
			return
		}
		
		let shouldFetchAndMergeArticles = timelineFetcherContainsAnyFeed(feeds) || timelineFetcherContainsAnyPseudoFeed()
		if shouldFetchAndMergeArticles {
			queueFetchAndMergeArticles()
		}
	}

	// MARK: API
	
	func shadowNodesFor(section: Int) -> [Node] {
		return shadowTable[section]
	}
	
	func cappedIndexPath(_ indexPath: IndexPath) -> IndexPath {
		guard indexPath.section < shadowTable.count && indexPath.row < shadowTable[indexPath.section].count else {
			return IndexPath(row: shadowTable[shadowTable.count - 1].count - 1, section: shadowTable.count - 1)
		}
		return indexPath
	}
	
	func unreadCountFor(_ node: Node) -> Int {
		// The coordinator supplies the unread count for the currently selected feed node
		if let indexPath = currentFeedIndexPath, let selectedNode = nodeFor(indexPath), selectedNode == node {
			return unreadCount
		}
		if let unreadCountProvider = node.representedObject as? UnreadCountProvider {
			return unreadCountProvider.unreadCount
		}
		return 0
	}
	
	func refreshTimeline() {
		fetchAndReplaceArticlesAsync(animated: true) {
			self.masterTimelineViewController?.reinitializeArticles()
		}
	}
	
	func showAllFeeds() {
		treeControllerDelegate.isReadFiltered = false
		rebuildBackingStores()
	}
	
	func hideReadFeeds() {
		treeControllerDelegate.isReadFiltered = true
		rebuildBackingStores()
	}
	
	func showAllArticles() {
		if let feedID = timelineFeed?.feedID {
			readFilterEnabledTable[feedID] = false
		}
		refreshTimeline()
	}
	
	func hideReadArticles() {
		if let feedID = timelineFeed?.feedID {
			readFilterEnabledTable[feedID] = true
		}
		refreshTimeline()
	}
	
	func isExpanded(_ node: Node) -> Bool {
		if let containerID = (node.representedObject as? ContainerIdentifiable)?.containerID {
			return expandedTable.contains(containerID)
		}
		return false
	}
		
	func expand(_ node: Node) {
		markExpanded(node)
		animatingChanges = true
		rebuildShadowTable()
		animatingChanges = false
	}
	
	func expandAllSectionsAndFolders() {
		for sectionNode in treeController.rootNode.childNodes {
			markExpanded(sectionNode)
			for topLevelNode in sectionNode.childNodes {
				if topLevelNode.representedObject is Folder {
					markExpanded(topLevelNode)
				}
			}
		}
		animatingChanges = true
		rebuildShadowTable()
		animatingChanges = false
	}
	
	func collapse(_ node: Node) {
		unmarkExpanded(node)
		animatingChanges = true
		rebuildShadowTable()
		animatingChanges = false
	}
	
	func collapseAllFolders() {
		for sectionNode in treeController.rootNode.childNodes {
			unmarkExpanded(sectionNode)
			for topLevelNode in sectionNode.childNodes {
				if topLevelNode.representedObject is Folder {
					unmarkExpanded(topLevelNode)
				}
			}
		}
		animatingChanges = true
		rebuildShadowTable()
		animatingChanges = false
	}
	
	func masterFeedIndexPathForCurrentTimeline() -> IndexPath? {
		guard let node = treeController.rootNode.descendantNodeRepresentingObject(timelineFeed as AnyObject) else {
			return nil
		}
		return indexPathFor(node)
	}
	
	func selectFeed(_ indexPath: IndexPath?, animated: Bool, deselectArticle: Bool = true, completion: (() -> Void)? = nil) {
		guard indexPath != currentFeedIndexPath else {
			completion?()
			return
		}
		
		currentFeedIndexPath = indexPath
		masterFeedViewController.updateFeedSelection(animated: animated)

		emptyTheTimeline()
		if deselectArticle {
			selectArticle(nil)
		}

		if let ip = indexPath, let node = nodeFor(ip), let feed = node.representedObject as? Feed {
			
			self.activityManager.selecting(feed: feed)
			self.installTimelineControllerIfNecessary(animated: animated)
			setTimelineFeed(feed, animated: false) {
				completion?()
			}
			
		} else {
			
			setTimelineFeed(nil, animated: false) {
				self.activityManager.invalidateSelecting()
				if self.rootSplitViewController.isCollapsed && self.navControllerForTimeline().viewControllers.last is MasterTimelineViewController {
					self.navControllerForTimeline().popViewController(animated: animated)
				}
				completion?()
			}
			
		}
		
	}
	
	func selectPrevFeed() {
		if let indexPath = prevFeedIndexPath {
			selectFeed(indexPath, animated: true)
		}
	}
	
	func selectNextFeed() {
		if let indexPath = nextFeedIndexPath {
			selectFeed(indexPath, animated: true)
		}
	}
	
	func selectTodayFeed() {
		masterFeedViewController?.ensureSectionIsExpanded(0) {
			self.selectFeed(IndexPath(row: 0, section: 0), animated: true)
		}
	}

	func selectAllUnreadFeed() {
		masterFeedViewController?.ensureSectionIsExpanded(0) {
			self.selectFeed(IndexPath(row: 1, section: 0), animated: true)
		}
	}

	func selectStarredFeed() {
		masterFeedViewController?.ensureSectionIsExpanded(0) {
			self.selectFeed(IndexPath(row: 2, section: 0), animated: true)
		}
	}

	func selectArticle(_ article: Article?, animated: Bool = false) {
		guard article != currentArticle else { return }
		
		stopArticleExtractor()
		currentArticle = article
		activityManager.reading(feed: timelineFeed, article: article)
		
		if article == nil {
			if rootSplitViewController.isCollapsed {
				if masterNavigationController.children.last is ArticleViewController {
					masterNavigationController.popViewController(animated: animated)
				}
			} else {
				articleViewController?.state = .noSelection
			}
			masterTimelineViewController?.updateArticleSelection(animated: animated)
			return
		}
		
		let currentArticleViewController: ArticleViewController
		if articleViewController == nil {
			currentArticleViewController = installArticleController(animated: animated)
		} else {
			currentArticleViewController = articleViewController!
		}
		
		masterTimelineViewController?.updateArticleSelection(animated: animated)
		
		if article!.webFeed?.isArticleExtractorAlwaysOn ?? false {
			startArticleExtractorForCurrentLink()
			currentArticleViewController.state = .loading
		} else {
			currentArticleViewController.state = .article(article!)
		}
		
		markArticles(Set([article!]), statusKey: .read, flag: true)
		
	}
	
	func beginSearching() {
		isSearching = true
		savedSearchArticles = articles
		savedSearchArticleIds = Set(articles.map { $0.articleID })
		setTimelineFeed(nil, animated: true)
		selectArticle(nil)
	}

	func endSearching() {
		if let ip = currentFeedIndexPath, let node = nodeFor(ip), let feed = node.representedObject as? Feed {
			timelineFeed = feed
			masterTimelineViewController?.reinitializeArticles()
			replaceArticles(with: savedSearchArticles!, animated: true)
		} else {
			setTimelineFeed(nil, animated: true)
		}
		
		lastSearchString = ""
		lastSearchScope = nil
		savedSearchArticleIds = nil
		savedSearchArticles = nil
		isSearching = false
		selectArticle(nil)
	}
	
	func searchArticles(_ searchString: String, _ searchScope: SearchScope) {
		
		guard isSearching else { return }
		
		if searchString.count < 3 {
			setTimelineFeed(nil, animated: true)
			return
		}
		
		if searchString != lastSearchString || searchScope != lastSearchScope {
			
			switch searchScope {
			case .global:
				setTimelineFeed(SmartFeed(delegate: SearchFeedDelegate(searchString: searchString)), animated: true)
			case .timeline:
				setTimelineFeed(SmartFeed(delegate: SearchTimelineFeedDelegate(searchString: searchString, articleIDs: savedSearchArticleIds!)), animated: true)
			}
			
			lastSearchString = searchString
			lastSearchScope = searchScope
		}
		
	}
	
	func selectPrevArticle() {
		if let article = prevArticle {
			selectArticle(article)
		}
	}
	
	func selectNextArticle() {
		if let article = nextArticle {
			selectArticle(article)
		}
	}
	
	func selectFirstUnread() {
		if selectFirstUnreadArticleInTimeline() {
			activityManager.selectingNextUnread()
		}
	}
	
	func selectPrevUnread() {
		
		// This should never happen, but I don't want to risk throwing us
		// into an infinate loop searching for an unread that isn't there.
		if appDelegate.unreadCount < 1 {
			return
		}
		
		if selectPrevUnreadArticleInTimeline() {
			return
		}
		
		selectPrevUnreadFeedFetcher()
		selectPrevUnreadArticleInTimeline()
	}

	func selectNextUnread() {
		
		// This should never happen, but I don't want to risk throwing us
		// into an infinate loop searching for an unread that isn't there.
		if appDelegate.unreadCount < 1 {
			return
		}
		
		if selectNextUnreadArticleInTimeline() {
			activityManager.selectingNextUnread()
			return
		}
		
		selectNextUnreadFeed() {
			if self.selectNextUnreadArticleInTimeline() {
				self.activityManager.selectingNextUnread()
			}
		}

	}
	
	func scrollOrGoToNextUnread() {
		if articleViewController?.canScrollDown() ?? false {
			articleViewController?.scrollPageDown()
		} else {
			selectNextUnread()
		}
	}
	
	func markAllAsRead(_ articles: [Article]) {
		markArticlesWithUndo(articles, statusKey: .read, flag: true)
	}
	
	func markAllAsReadInTimeline() {
		markAllAsRead(articles)
		masterNavigationController.popViewController(animated: true)
	}
	
	func markAsReadOlderArticlesInTimeline() {
		if let article = currentArticle {
			markAsReadOlderArticlesInTimeline(article)
		}
	}
	
	func markAsReadOlderArticlesInTimeline(_ article: Article) {
		let articlesToMark = articles.filter { $0.logicalDatePublished < article.logicalDatePublished }
		if articlesToMark.isEmpty {
			return
		}
		markAllAsRead(articlesToMark)
	}
	
	func markAsReadForCurrentArticle() {
		if let article = currentArticle {
			markArticlesWithUndo([article], statusKey: .read, flag: true)
		}
	}
	
	func markAsUnreadForCurrentArticle() {
		if let article = currentArticle {
			markArticlesWithUndo([article], statusKey: .read, flag: false)
		}
	}
	
	func toggleReadForCurrentArticle() {
		if let article = currentArticle {
			toggleRead(article)
		}
	}
	
	func toggleRead(_ article: Article) {
		markArticlesWithUndo([article], statusKey: .read, flag: !article.status.read)
	}

	func toggleStarredForCurrentArticle() {
		if let article = currentArticle {
			toggleStar(article)
		}
	}
	
	func toggleStar(_ article: Article) {
		markArticlesWithUndo([article], statusKey: .starred, flag: !article.status.starred)
	}

	func discloseFeed(_ feed: WebFeed, animated: Bool, completion: (() -> Void)? = nil) {
		masterFeedViewController.discloseFeed(feed, animated: animated) {
			completion?()
		}
	}
	
	func showStatusBar() {
		prefersStatusBarHidden = false
		UIView.animate(withDuration: 0.15) {
			self.rootSplitViewController.setNeedsStatusBarAppearanceUpdate()
		}
	}
	
	func hideStatusBar() {
		prefersStatusBarHidden = true
		UIView.animate(withDuration: 0.15) {
			self.rootSplitViewController.setNeedsStatusBarAppearanceUpdate()
		}
	}
	
	func showSettings() {
		let settingsNavController = UIStoryboard.settings.instantiateInitialViewController() as! UINavigationController
		let settingsViewController = settingsNavController.topViewController as! SettingsViewController
		settingsNavController.modalPresentationStyle = .formSheet
		settingsViewController.presentingParentController = rootSplitViewController
		rootSplitViewController.present(settingsNavController, animated: true)
	}
	
	func showAccountInspector(for account: Account) {
		let accountInspectorNavController =
			UIStoryboard.inspector.instantiateViewController(identifier: "AccountInspectorNavigationViewController") as! UINavigationController
		let accountInspectorController = accountInspectorNavController.topViewController as! AccountInspectorViewController
		accountInspectorNavController.modalPresentationStyle = .formSheet
		accountInspectorNavController.preferredContentSize = AccountInspectorViewController.preferredContentSizeForFormSheetDisplay
		accountInspectorController.isModal = true
		accountInspectorController.account = account
		rootSplitViewController.present(accountInspectorNavController, animated: true)
	}
	
	func showFeedInspector() {
		guard let feed = timelineFeed as? WebFeed else {
			return
		}
		showFeedInspector(for: feed)
	}
	
	func showFeedInspector(for feed: WebFeed) {
		let feedInspectorNavController =
			UIStoryboard.inspector.instantiateViewController(identifier: "FeedInspectorNavigationViewController") as! UINavigationController
		let feedInspectorController = feedInspectorNavController.topViewController as! WebFeedInspectorViewController
		feedInspectorNavController.modalPresentationStyle = .formSheet
		feedInspectorNavController.preferredContentSize = WebFeedInspectorViewController.preferredContentSizeForFormSheetDisplay
		feedInspectorController.webFeed = feed
		rootSplitViewController.present(feedInspectorNavController, animated: true)
	}
	
	func showAdd(_ type: AddControllerType, initialFeed: String? = nil, initialFeedName: String? = nil) {
		selectFeed(nil, animated: false)

		let addViewController = UIStoryboard.add.instantiateInitialViewController() as! UINavigationController
		
		let containerController = addViewController.topViewController as! AddContainerViewController
		containerController.initialControllerType = type
		containerController.initialFeed = initialFeed
		containerController.initialFeedName = initialFeedName
		
		addViewController.modalPresentationStyle = .formSheet
		addViewController.preferredContentSize = AddContainerViewController.preferredContentSizeForFormSheetDisplay
		masterFeedViewController.present(addViewController, animated: true)
	}
	
	func showFullScreenImage(image: UIImage, transitioningDelegate: UIViewControllerTransitioningDelegate) {
		let imageVC = UIStoryboard.main.instantiateController(ofType: ImageViewController.self)
		imageVC.image = image
		imageVC.modalPresentationStyle = .currentContext
		imageVC.transitioningDelegate = transitioningDelegate
		rootSplitViewController.present(imageVC, animated: true)
	}
	
	func toggleArticleExtractor() {
		
		guard let article = currentArticle else {
			return
		}

		guard articleExtractor?.state != .processing else {
			stopArticleExtractor()
			articleViewController?.state = .article(article)
			return
		}
		
		guard !isShowingExtractedArticle else {
			isShowingExtractedArticle = false
			articleViewController?.articleExtractorButtonState = .off
			articleViewController?.state = .article(article)
			return
		}
		
		if let articleExtractor = articleExtractor, let extractedArticle = articleExtractor.article {
			if currentArticle?.preferredLink == articleExtractor.articleLink {
				isShowingExtractedArticle = true
				articleViewController?.articleExtractorButtonState = .on
				articleViewController?.state = .extracted(article, extractedArticle)
			}
		} else {
			startArticleExtractorForCurrentLink()
		}
		
	}
	
	func homePageURLForFeed(_ indexPath: IndexPath) -> URL? {
		guard let node = nodeFor(indexPath),
			let feed = node.representedObject as? WebFeed,
			let homePageURL = feed.homePageURL,
			let url = URL(string: homePageURL) else {
				return nil
		}
		return url
	}
	
	func showBrowserForFeed(_ indexPath: IndexPath) {
		if let url = homePageURLForFeed(indexPath) {
			UIApplication.shared.open(url, options: [:])
		}
	}
	
	func showBrowserForCurrentFeed() {
		if let ip = currentFeedIndexPath, let url = homePageURLForFeed(ip) {
			UIApplication.shared.open(url, options: [:])
		}
	}
	
	func showBrowserForArticle(_ article: Article) {
		guard let preferredLink = article.preferredLink, let url = URL(string: preferredLink) else {
			return
		}
		UIApplication.shared.open(url, options: [:])
	}

	func showBrowserForCurrentArticle() {
		guard let preferredLink = currentArticle?.preferredLink, let url = URL(string: preferredLink) else {
			return
		}
		UIApplication.shared.open(url, options: [:])
	}
	
	func navigateToFeeds() {
		masterFeedViewController?.focus()
		selectArticle(nil)
	}
	
	func navigateToTimeline() {
		if currentArticle == nil && articles.count > 0 {
			selectArticle(articles[0])
		}
		masterTimelineViewController?.focus()
	}
	
	func navigateToDetail() {
		articleViewController?.focus()
	}
	
}

// MARK: UISplitViewControllerDelegate

extension SceneCoordinator: UISplitViewControllerDelegate {
	
	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
		guard !isThreePanelMode else {
			return true
		}
		
		if let articleViewController = (secondaryViewController as? UINavigationController)?.topViewController as? ArticleViewController {
			masterNavigationController.pushViewController(articleViewController, animated: false)
			return false
		}
		
		return currentArticle == nil
	}
	
	func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
		guard !isThreePanelMode else {
			return subSplitViewController
		}
		
		guard currentArticle != nil else {
			let articleViewController = UIStoryboard.main.instantiateController(ofType: ArticleViewController.self)
			articleViewController.coordinator = self
			let controller = addNavControllerIfNecessary(articleViewController, showButton: true)
			return controller
		}
		
		if let articleViewController = masterNavigationController.viewControllers.last as? ArticleViewController {
			masterNavigationController.popViewController(animated: false)
			let controller = addNavControllerIfNecessary(articleViewController, showButton: true)
			return controller
		}
		
		return nil
	}
	
}

// MARK: UINavigationControllerDelegate

extension SceneCoordinator: UINavigationControllerDelegate {
	
	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		
		if UIApplication.shared.applicationState == .background {
			return
		}

		// If we are showing the Feeds and only the feeds start clearing stuff
		if viewController === masterFeedViewController && !isThreePanelMode && !isTimelineViewControllerPending {
			activityManager.invalidateCurrentActivities()
			selectFeed(nil, animated: true)
			return
		}

		// If we are using a phone and navigate away from the detail, clear up the article resources (including activity).
		// Don't clear it if we have pushed an ArticleViewController, but don't yet see it on the navigation stack.
		// This happens when we are going to the next unread and we need to grab another timeline to continue.  The
		// ArticleViewController will be pushed, but we will breifly show the Timeline.  Don't clear things out when that happens.
		if viewController === masterTimelineViewController && !isThreePanelMode && rootSplitViewController.isCollapsed && !isArticleViewControllerPending {
			stopArticleExtractor()
			currentArticle = nil
			masterTimelineViewController?.updateArticleSelection(animated: animated)
			activityManager.invalidateReading()

			// Restore any bars hidden by the article controller
			showStatusBar()
			navigationController.setNavigationBarHidden(false, animated: true)
			navigationController.setToolbarHidden(false, animated: true)
			return
		}
		
	}
	
}

// MARK: ArticleExtractorDelegate

extension SceneCoordinator: ArticleExtractorDelegate {
	
	func articleExtractionDidFail(with: Error) {
		stopArticleExtractor()
		articleViewController?.articleExtractorButtonState = .error
	}
	
	func articleExtractionDidComplete(extractedArticle: ExtractedArticle) {
		if let article = currentArticle, articleExtractor?.state != .cancelled {
			isShowingExtractedArticle = true
			articleViewController?.state = .extracted(article, extractedArticle)
			articleViewController?.articleExtractorButtonState = .on
		}
	}
	
}

// MARK: Private

private extension SceneCoordinator {

	func markArticlesWithUndo(_ articles: [Article], statusKey: ArticleStatus.Key, flag: Bool) {
		guard let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: articles, statusKey: statusKey, flag: flag, undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}
	
	func updateUnreadCount() {
		var count = 0
		for article in articles {
			if !article.status.read {
				count += 1
			}
		}
		unreadCount = count
	}
	
	func rebuildBackingStores(initialLoad: Bool = false, updateExpandedNodes: (() -> Void)? = nil) {
		if !animatingChanges && !BatchUpdate.shared.isPerforming {
			treeController.rebuild()
			updateExpandedNodes?()
			rebuildShadowTable()
			masterFeedViewController.reloadFeeds(initialLoad: initialLoad)
		}
	}
	
	func rebuildShadowTable() {
		shadowTable = [[Node]]()

		for i in 0..<treeController.rootNode.numberOfChildNodes {
			
			var result = [Node]()
			let sectionNode = treeController.rootNode.childAtIndex(i)!
			
			if isExpanded(sectionNode) {
				for node in sectionNode.childNodes {
					result.append(node)
					if isExpanded(node) {
						for child in node.childNodes {
							result.append(child)
						}
					}
				}
			}
			
			shadowTable.append(result)
			
		}
	}

	func nodeFor(_ indexPath: IndexPath) -> Node? {
		guard indexPath.section < shadowTable.count && indexPath.row < shadowTable[indexPath.section].count else {
			return nil
		}
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

	func indexPathFor(_ object: AnyObject) -> IndexPath? {
		guard let node = treeController.rootNode.descendantNodeRepresentingObject(object) else {
			return nil
		}
		return indexPathFor(node)
	}
	
	func setTimelineFeed(_ feed: Feed?, animated: Bool, completion: (() -> Void)? = nil) {
		timelineFeed = feed
		timelineMiddleIndexPath = nil
		
		fetchAndReplaceArticlesAsync(animated: animated) {
			self.masterTimelineViewController?.reinitializeArticles()
			completion?()
		}
	}
	
	func updateShowNamesAndIcons() {
		
		if timelineFeed is WebFeed {
			showFeedNames = false
		} else {
			showFeedNames = true
		}

		if showFeedNames {
			self.showIcons = true
			return
		}
		
		for article in articles {
			if let authors = article.authors {
				for author in authors {
					if author.avatarURL != nil {
						self.showIcons = true
						return
					}
				}
			}
		}
		
		self.showIcons = false
	}
	
	func markExpanded(_ node: Node) {
		if let containerID = (node.representedObject as? ContainerIdentifiable)?.containerID {
			expandedTable.insert(containerID)
		}
	}
	
	func unmarkExpanded(_ node: Node) {
		if let containerID = (node.representedObject as? ContainerIdentifiable)?.containerID {
			expandedTable.remove(containerID)
		}
	}

	// MARK: Select Prev Unread

	@discardableResult
	func selectPrevUnreadArticleInTimeline() -> Bool {
		let startingRow: Int = {
			if let articleRow = currentArticleRow {
				return articleRow
			} else {
				return articles.count - 1
			}
		}()
		
		return selectPrevArticleInTimeline(startingRow: startingRow)
	}
	
	func selectPrevArticleInTimeline(startingRow: Int) -> Bool {
		
		guard startingRow >= 0 else {
			return false
		}
		
		for i in (0...startingRow).reversed() {
			let article = articles[i]
			if !article.status.read {
				selectArticle(article)
				return true
			}
		}
		
		return false
		
	}
	
	func selectPrevUnreadFeedFetcher() {
		
		let indexPath: IndexPath = {
			if currentFeedIndexPath == nil {
				return IndexPath(row: 0, section: 0)
			} else {
				return currentFeedIndexPath!
			}
		}()

		// Increment or wrap around the IndexPath
		let nextIndexPath: IndexPath = {
			if indexPath.row - 1 < 0 {
				if indexPath.section - 1 < 0 {
					return IndexPath(row: shadowTable[shadowTable.count - 1].count - 1, section: shadowTable.count - 1)
				} else {
					return IndexPath(row: shadowTable[indexPath.section - 1].count - 1, section: indexPath.section - 1)
				}
			} else {
				return IndexPath(row: indexPath.row - 1, section: indexPath.section)
			}
		}()
		
		if selectPrevUnreadFeedFetcher(startingWith: nextIndexPath) {
			return
		}
		let maxIndexPath = IndexPath(row: shadowTable[shadowTable.count - 1].count - 1, section: shadowTable.count - 1)
		selectPrevUnreadFeedFetcher(startingWith: maxIndexPath)
		
	}
	
	@discardableResult
	func selectPrevUnreadFeedFetcher(startingWith indexPath: IndexPath) -> Bool {
		
		for i in (0...indexPath.section).reversed() {
			
			let startingRow: Int = {
				if indexPath.section == i {
					return indexPath.row
				} else {
					return shadowTable[i].count - 1
				}
			}()
			
			for j in (0...startingRow).reversed() {
				
				let prevIndexPath = IndexPath(row: j, section: i)
				guard let node = nodeFor(prevIndexPath), let unreadCountProvider = node.representedObject as? UnreadCountProvider else {
					assertionFailure()
					return true
				}
				
				if isExpanded(node) {
					continue
				}
				
				if unreadCountProvider.unreadCount > 0 {
					selectFeed(prevIndexPath, animated: true)
					return true
				}
				
			}
			
		}
		
		return false
		
	}
	
	// MARK: Select Next Unread
	
	@discardableResult
	func selectFirstUnreadArticleInTimeline() -> Bool {
		return selectNextArticleInTimeline(startingRow: 0, animated: true)
	}
	
	@discardableResult
	func selectNextUnreadArticleInTimeline() -> Bool {
		let startingRow: Int = {
			if let articleRow = currentArticleRow {
				return articleRow + 1
			} else {
				return 0
			}
		}()
		
		return selectNextArticleInTimeline(startingRow: startingRow, animated: false)
	}
	
	func selectNextArticleInTimeline(startingRow: Int, animated: Bool) -> Bool {
		
		guard startingRow < articles.count else {
			return false
		}
		
		for i in startingRow..<articles.count {
			let article = articles[i]
			if !article.status.read {
				selectArticle(article, animated: animated)
				return true
			}
		}
		
		return false
		
	}
	
	func selectNextUnreadFeed(completion: @escaping () -> Void) {
		
		let indexPath: IndexPath = {
			if currentFeedIndexPath == nil {
				return IndexPath(row: -1, section: 0)
			} else {
				return currentFeedIndexPath!
			}
		}()
		
		// Increment or wrap around the IndexPath
		let nextIndexPath: IndexPath = {
			if indexPath.row + 1 >= shadowTable[indexPath.section].count {
				if indexPath.section + 1 >= shadowTable.count {
					return IndexPath(row: 0, section: 0)
				} else {
					return IndexPath(row: 0, section: indexPath.section + 1)
				}
			} else {
				return IndexPath(row: indexPath.row + 1, section: indexPath.section)
			}
		}()
		
		selectNextUnreadFeed(startingWith: nextIndexPath) { found in
			if !found {
				self.selectNextUnreadFeed(startingWith: IndexPath(row: 0, section: 0)) { _ in
					completion()
				}
			} else {
				completion()
			}
		}
		
	}
	
	func selectNextUnreadFeed(startingWith indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
		
		for i in indexPath.section..<shadowTable.count {
			
			let startingRow: Int = {
				if indexPath.section == i {
					return indexPath.row
				} else {
					return 0
				}
			}()
			
			for j in startingRow..<shadowTable[indexPath.section].count {
				
				let nextIndexPath = IndexPath(row: j, section: i)
				guard let node = nodeFor(nextIndexPath), let unreadCountProvider = node.representedObject as? UnreadCountProvider else {
					assertionFailure()
					completion(false)
					return
				}
				
				if isExpanded(node) {
					continue
				}
				
				if unreadCountProvider.unreadCount > 0 {
					selectFeed(nextIndexPath, animated: false, deselectArticle: false) {
						self.currentArticle = nil
						completion(true)
					}
					return
				}
				
			}
			
		}
		
		completion(false)
		
	}
	
	// MARK: Fetching Articles
	
	func startArticleExtractorForCurrentLink() {
		if let link = currentArticle?.preferredLink, let extractor = ArticleExtractor(link) {
			extractor.delegate = self
			extractor.process()
			articleExtractor = extractor
			articleViewController?.articleExtractorButtonState = .animated
		}
	}

	func stopArticleExtractor() {
		articleExtractor?.cancel()
		articleExtractor = nil
		isShowingExtractedArticle = false
		articleViewController?.articleExtractorButtonState = .off
	}
	
	func emptyTheTimeline() {
		if !articles.isEmpty {
			replaceArticles(with: Set<Article>(), animated: false)
		}
	}
	
	func sortParametersDidChange() {
		replaceArticles(with: Set(articles), animated: true)
	}
		
	func replaceArticles(with unsortedArticles: Set<Article>, animated: Bool) {
		let sortedArticles = Array(unsortedArticles).sortedByDate(sortDirection, groupByFeed: groupByFeed)
		replaceArticles(with: sortedArticles, animated: animated)
	}
	
	func replaceArticles(with sortedArticles: ArticleArray, animated: Bool) {
		if articles != sortedArticles {
			articles = sortedArticles
			updateShowNamesAndIcons()
			updateUnreadCount()
			masterTimelineViewController?.reloadArticles(animated: animated)
		}
	}
	
	func queueFetchAndMergeArticles() {
		fetchAndMergeArticlesQueue.add(self, #selector(fetchAndMergeArticles))
	}
	
	@objc func fetchAndMergeArticles() {
		
		guard let timelineFeed = timelineFeed else {
			return
		}
		
		fetchUnsortedArticlesAsync(for: [timelineFeed]) { [weak self] (unsortedArticles) in
			// Merge articles by articleID. For any unique articleID in current articles, add to unsortedArticles.
			guard let strongSelf = self else {
				return
			}
			let unsortedArticleIDs = unsortedArticles.articleIDs()
			var updatedArticles = unsortedArticles
			for article in strongSelf.articles {
				if !unsortedArticleIDs.contains(article.articleID) {
					updatedArticles.insert(article)
				}
			}

			strongSelf.replaceArticles(with: updatedArticles, animated: true)
		}
		
	}
	
	func cancelPendingAsyncFetches() {
		fetchSerialNumber += 1
		fetchRequestQueue.cancelAllRequests()
	}

	func fetchAndReplaceArticlesAsync(animated: Bool, completion: @escaping () -> Void) {
		// To be called when we need to do an entire fetch, but an async delay is okay.
		// Example: we have the Today feed selected, and the calendar day just changed.
		cancelPendingAsyncFetches()
		guard let timelineFeed = timelineFeed else {
			emptyTheTimeline()
			completion()
			return
		}
		
		var fetchers = [ArticleFetcher]()
		fetchers.append(timelineFeed)
		if exceptionArticleFetcher != nil {
			fetchers.append(exceptionArticleFetcher!)
			exceptionArticleFetcher = nil
		}
		
		fetchUnsortedArticlesAsync(for: fetchers) { [weak self] (articles) in
			self?.replaceArticles(with: articles, animated: animated)
			completion()
		}
		
	}

	func fetchUnsortedArticlesAsync(for representedObjects: [Any], callback: @escaping ArticleSetBlock) {
		// The callback will *not* be called if the fetch is no longer relevant — that is,
		// if it’s been superseded by a newer fetch, or the timeline was emptied, etc., it won’t get called.
		precondition(Thread.isMainThread)
		cancelPendingAsyncFetches()
		
		let fetchOperation = FetchRequestOperation(id: fetchSerialNumber, readFilter: isReadArticlesFiltered, representedObjects: representedObjects) { [weak self] (articles, operation) in
			precondition(Thread.isMainThread)
			guard !operation.isCanceled, let strongSelf = self, operation.id == strongSelf.fetchSerialNumber else {
				return
			}
			callback(articles)
		}
		
		fetchRequestQueue.add(fetchOperation)
	}

	func timelineFetcherContainsAnyPseudoFeed() -> Bool {
		if timelineFeed is PseudoFeed {
			return true
		}
		return false
	}
	
	func timelineFetcherContainsAnyFolder() -> Bool {
		if timelineFeed is Folder {
			return true
		}
		return false
	}
	
	func timelineFetcherContainsAnyFeed(_ feeds: Set<WebFeed>) -> Bool {
		
		// Return true if there’s a match or if a folder contains (recursively) one of feeds
		
		if let feed = timelineFeed as? WebFeed {
			for oneFeed in feeds {
				if feed.webFeedID == oneFeed.webFeedID || feed.url == oneFeed.url {
					return true
				}
			}
		} else if let folder = timelineFeed as? Folder {
			for oneFeed in feeds {
				if folder.hasWebFeed(with: oneFeed.webFeedID) || folder.hasWebFeed(withURL: oneFeed.url) {
					return true
				}
			}
		}
		
		return false
		
	}
	
	// MARK: Three Panel Mode
	
	func installTimelineControllerIfNecessary(animated: Bool) {
		if navControllerForTimeline().viewControllers.filter({ $0 is MasterTimelineViewController }).count < 1 {
			isTimelineViewControllerPending = true
			masterTimelineViewController = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
			masterTimelineViewController!.coordinator = self
			navControllerForTimeline().pushViewController(masterTimelineViewController!, animated: animated)
		}
	}
	
	@discardableResult
	func installArticleController(_ recycledArticleController: ArticleViewController? = nil, animated: Bool) -> ArticleViewController {

		isArticleViewControllerPending = true

		let articleController: ArticleViewController = {
			if let controller = recycledArticleController {
				return controller
			} else {
				let controller = UIStoryboard.main.instantiateController(ofType: ArticleViewController.self)
				controller.coordinator = self
				return controller
			}
		}()
				
		if let subSplit = subSplitViewController {
			let controller = addNavControllerIfNecessary(articleController, showButton: false)
			subSplit.showDetailViewController(controller, sender: self)
		} else if rootSplitViewController.isCollapsed || wasRootSplitViewControllerCollapsed {
			masterNavigationController.pushViewController(articleController, animated: animated)
		} else {
			let controller = addNavControllerIfNecessary(articleController, showButton: true)
			rootSplitViewController.showDetailViewController(controller, sender: self)
  	 	}
		
		// We have to do a full reload when installing an article controller.  We may have changed color contexts
		// and need to update the article colors.  An example is in dark mode.  Split screen doesn't use true black
		// like darkmode usually does.
		articleController.fullReload()
		return articleController
		
	}
	
	func addNavControllerIfNecessary(_ controller: UIViewController, showButton: Bool) -> UIViewController {
		
		// You will sometimes get a compact horizontal size class while in three panel mode.  Dunno why it lies.
		if rootSplitViewController.traitCollection.horizontalSizeClass == .compact && !isThreePanelMode {
			
			return controller
			
		} else {
			
			let navController = InteractiveNavigationController.template(rootViewController: controller)
			navController.isToolbarHidden = false
			
			if showButton {
				controller.navigationItem.leftBarButtonItem = rootSplitViewController.displayModeButtonItem
				controller.navigationItem.leftItemsSupplementBackButton = true
			} else {
				controller.navigationItem.leftBarButtonItem = nil
				controller.navigationItem.leftItemsSupplementBackButton = false
			}
			
			return navController
			
		}
		
	}

	func installSubSplit() {
		rootSplitViewController.preferredPrimaryColumnWidthFraction = 0.30
		
		subSplitViewController = UISplitViewController()
		subSplitViewController!.preferredDisplayMode = .allVisible
		subSplitViewController!.viewControllers = [InteractiveNavigationController.template()]
		subSplitViewController!.preferredPrimaryColumnWidthFraction = 0.4285
		
		rootSplitViewController.showDetailViewController(subSplitViewController!, sender: self)
		rootSplitViewController.setOverrideTraitCollection(UITraitCollection(horizontalSizeClass: .regular), forChild: subSplitViewController!)
	}
	
	func navControllerForTimeline() -> UINavigationController {
		if let subSplit = subSplitViewController {
			return subSplit.viewControllers.first as! UINavigationController
		} else {
			return masterNavigationController
		}
	}
	
	func configureThreePanelMode() {
		let recycledArticleController = articleViewController
		defer {
			masterNavigationController.viewControllers = [masterFeedViewController]
		}
		
		
		if rootSplitViewController.viewControllers.last is InteractiveNavigationController {
			_ = rootSplitViewController.viewControllers.popLast()
		}

		installSubSplit()
		installTimelineControllerIfNecessary(animated: false)
		masterTimelineViewController?.navigationItem.leftBarButtonItem = rootSplitViewController.displayModeButtonItem
		masterTimelineViewController?.navigationItem.leftItemsSupplementBackButton = true

		installArticleController(recycledArticleController, animated: false)
		
		masterFeedViewController.restoreSelectionIfNecessary(adjustScroll: true)
		masterTimelineViewController!.restoreSelectionIfNecessary(adjustScroll: false)
	}
	
	func configureStandardPanelMode() {
		let recycledArticleController = articleViewController
		rootSplitViewController.preferredPrimaryColumnWidthFraction = UISplitViewController.automaticDimension
		
		// Set the is Pending flags early to prevent the navigation controller delegate from thinking that we
		// swiping around in the user interface
		isTimelineViewControllerPending = true
		isArticleViewControllerPending = true

		masterNavigationController.viewControllers = [masterFeedViewController]
		if rootSplitViewController.viewControllers.last is UISplitViewController {
			subSplitViewController = nil
			_ = rootSplitViewController.viewControllers.popLast()
		}
			
		if currentFeedIndexPath != nil {
			masterTimelineViewController = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
			masterTimelineViewController!.coordinator = self
			masterNavigationController.pushViewController(masterTimelineViewController!, animated: false)
		}

		installArticleController(recycledArticleController, animated: false)
	}
	
	// MARK: NSUserActivity
	
	func windowState() -> [AnyHashable: Any] {
		let containerExpandedWindowState = expandedTable.map( { $0.userInfo })
		var readArticlesFilterState = [[AnyHashable: AnyHashable]: Bool]()
		for key in readFilterEnabledTable.keys {
			readArticlesFilterState[key.userInfo] = readFilterEnabledTable[key]
		}
		return [
			UserInfoKey.readFeedsFilterState: isReadFeedsFiltered,
			UserInfoKey.containerExpandedWindowState: containerExpandedWindowState,
			UserInfoKey.readArticlesFilterState: readArticlesFilterState
		]
	}
	
	func handleSelectFeed(_ userInfo: [AnyHashable : Any]?) {
		guard let userInfo = userInfo,
			let feedIdentifierUserInfo = userInfo[UserInfoKey.feedIdentifier] as? [AnyHashable : AnyHashable],
			let feedIdentifier = FeedIdentifier(userInfo: feedIdentifierUserInfo) else {
				return
		}

		treeControllerDelegate.addFilterException(feedIdentifier)
		masterFeedViewController.restoreSelection = true
		

		switch feedIdentifier {
		
		case .smartFeed:
			guard let smartFeed = SmartFeedsController.shared.find(by: feedIdentifier) else { return }
			if let indexPath = indexPathFor(smartFeed) {
				selectFeed(indexPath, animated: false)
			}
		
		case .script:
			break
		
		case .folder(let accountID, let folderName):
			guard let accountNode = findAccountNode(accountID: accountID), let folderNode = findFolderNode(folderName: folderName, beginningAt: accountNode) else {
				return
			}
			if let indexPath = indexPathFor(folderNode) {
				selectFeed(indexPath, animated: false)
			}
		
		case .webFeed(let accountID, let webFeedID):
			guard let accountNode = findAccountNode(accountID: accountID), let feedNode = findWebFeedNode(webFeedID: webFeedID, beginningAt: accountNode) else {
				return
			}
			if let folder = feedNode.parent?.representedObject as? Folder, let folderFeedID = folder.feedID {
				treeControllerDelegate.addFilterException(folderFeedID)
			}
			if let feed = feedNode.representedObject as? WebFeed {
				discloseFeed(feed, animated: false)
			}
			
		}
	}
	
	func handleReadArticle(_ userInfo: [AnyHashable : Any]?) {
		guard let userInfo = userInfo else { return }
		
		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable : Any],
			let accountID = articlePathUserInfo[ArticlePathKey.accountID] as? String,
			let accountName = articlePathUserInfo[ArticlePathKey.accountName] as? String,
			let webFeedID = articlePathUserInfo[ArticlePathKey.webFeedID] as? String,
			let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String,
			let accountNode = findAccountNode(accountID: accountID, accountName: accountName),
			let account = accountNode.representedObject as? Account else {
				return
		}
		
		exceptionArticleFetcher = SingleArticleFetcher(account: account, articleID: articleID)

		if restoreFeedSelection(userInfo, accountID: accountID, webFeedID: webFeedID, articleID: articleID) {
			return
		}
		
		guard let webFeedNode = findWebFeedNode(webFeedID: webFeedID, beginningAt: accountNode),
			let webFeed = webFeedNode.representedObject as? WebFeed,
			let webFeedFeedID = webFeed.feedID else {
				return
		}
		
		treeControllerDelegate.addFilterException(webFeedFeedID)
		addParentFolderToFilterExceptions(webFeedNode)
		
		discloseFeed(webFeed, animated: false) {
			self.selectArticleInCurrentFeed(articleID)
		}
	}
	
	func restoreFeedSelection(_ userInfo: [AnyHashable : Any], accountID: String, webFeedID: String, articleID: String) -> Bool {
		guard let feedIdentifierUserInfo = userInfo[UserInfoKey.feedIdentifier] as? [AnyHashable : AnyHashable],
			let feedIdentifier = FeedIdentifier(userInfo: feedIdentifierUserInfo) else {
				return false
		}

		masterFeedViewController.restoreSelection = true
		
		switch feedIdentifier {

		case .smartFeed:
			guard let smartFeed = SmartFeedsController.shared.find(by: feedIdentifier) else { return false }
			if let indexPath = indexPathFor(smartFeed) {
				selectFeed(indexPath, animated: false) {
					self.selectArticleInCurrentFeed(articleID)
				}
				treeControllerDelegate.addFilterException(feedIdentifier)
				return true
			}
		
		case .script:
			return false
		
		case .folder(let accountID, let folderName):
			guard let accountNode = findAccountNode(accountID: accountID),
				let folderNode = findFolderNode(folderName: folderName, beginningAt: accountNode) else {
					return false
			}
			let found = selectFeedAndArticle(feedNode: folderNode, articleID: articleID)
			if found {
				treeControllerDelegate.addFilterException(feedIdentifier)
			}
			return found
		
		case .webFeed:
			guard let accountNode = findAccountNode(accountID: accountID), let webFeedNode = findWebFeedNode(webFeedID: webFeedID, beginningAt: accountNode) else {
				return false
			}
			let found = selectFeedAndArticle(feedNode: webFeedNode, articleID: articleID)
			if found {
				treeControllerDelegate.addFilterException(feedIdentifier)
				addParentFolderToFilterExceptions(webFeedNode)
			}
			return found
			
		}
		
		return false
	}
	
	func findAccountNode(accountID: String, accountName: String? = nil) -> Node? {
		if let node = treeController.rootNode.descendantNode(where: { ($0.representedObject as? Account)?.accountID == accountID }) {
			return node
		}

		if let accountName = accountName, let node = treeController.rootNode.descendantNode(where: { ($0.representedObject as? Account)?.nameForDisplay == accountName }) {
			return node
		}

		return nil
	}
	
	func findFolderNode(folderName: String, beginningAt startingNode: Node) -> Node? {
		if let node = startingNode.descendantNode(where: { ($0.representedObject as? Folder)?.nameForDisplay == folderName }) {
			return node
		}
		return nil
	}

	func findWebFeedNode(webFeedID: String, beginningAt startingNode: Node) -> Node? {
		if let node = startingNode.descendantNode(where: { ($0.representedObject as? WebFeed)?.webFeedID == webFeedID }) {
			return node
		}
		return nil
	}
	
	func selectFeedAndArticle(feedNode: Node, articleID: String) -> Bool {
		if let feedIndexPath = indexPathFor(feedNode) {
			selectFeed(feedIndexPath, animated: false) {
				self.selectArticleInCurrentFeed(articleID)
			}
			return true
		}
		return false
	}
	
	func selectArticleInCurrentFeed(_ articleID: String) {
		if let article = self.articles.first(where: { $0.articleID == articleID }) {
			self.selectArticle(article)
		}
	}
	
	func addParentFolderToFilterExceptions(_ feedNode: Node) {
		if let folder = feedNode.parent?.representedObject as? Folder, let folderFeedID = folder.feedID {
			treeControllerDelegate.addFilterException(folderFeedID)
		}
	}
	
}
