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
import SafariServices

protocol MainControllerIdentifiable {
	var mainControllerIdentifer: MainControllerIdentifier { get }
}

enum MainControllerIdentifier {
	case none
	case masterFeed
	case masterTimeline
	case article
}

enum SearchScope: Int {
	case timeline = 0
	case global = 1
}

enum ShowFeedName {
	case none
	case byline
	case feed
}

struct FeedNode: Hashable {
	var node: Node
	var feedID: FeedIdentifier
	
	init(_ node: Node) {
		self.node = node
		self.feedID = (node.representedObject as! Feed).feedID!
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(feedID)
	}
}

class SceneCoordinator: NSObject, UndoableCommandRunner {
	
	var undoableCommands = [UndoableCommand]()
	var undoManager: UndoManager? {
		return rootSplitViewController.undoManager
	}
	
	lazy var webViewProvider = WebViewProvider(coordinator: self)
	
	private var activityManager = ActivityManager()
	
	private var rootSplitViewController: RootSplitViewController!
	private var masterFeedViewController: MasterFeedViewController!
	private var masterTimelineViewController: MasterTimelineViewController?
	private var articleViewController: ArticleViewController?

	private var lastMainControllerToAppear = MainControllerIdentifier.none

	private let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5)
	private let rebuildBackingStoresQueue = CoalescingQueue(name: "Rebuild The Backing Stores", interval: 0.5)
	private var fetchSerialNumber = 0
	private let fetchRequestQueue = FetchRequestQueue()
	
	// Which Containers are expanded
	private var expandedTable = Set<ContainerIdentifier>()
	
	// Which Containers used to be expanded. Reset by rebuilding the Shadow Table.
	private var lastExpandedTable = Set<ContainerIdentifier>()
	
	// Which Feeds have the Read Articles Filter enabled
	private var readFilterEnabledTable = [FeedIdentifier: Bool]()
	
	// Flattened tree structure for the Sidebar
	private var shadowTable = [(sectionID: String, feedNodes: [FeedNode])]()
	
	private(set) var preSearchTimelineFeed: Feed?
	private var lastSearchString = ""
	private var lastSearchScope: SearchScope? = nil
	private var isSearching: Bool = false
	private var savedSearchArticles: ArticleArray? = nil
	private var savedSearchArticleIds: Set<String>? = nil
	
	private(set) var sortDirection = AppDefaults.shared.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortParametersDidChange()
			}
		}
	}
	
	private(set) var groupByFeed = AppDefaults.shared.timelineGroupByFeed {
		didSet {
			if groupByFeed != oldValue {
				sortParametersDidChange()
			}
		}
	}
	
	var prefersStatusBarHidden = false
	
	private let treeControllerDelegate = WebFeedTreeControllerDelegate()
	private let treeController: TreeController
	
	var stateRestorationActivity: NSUserActivity {
		let activity = activityManager.stateRestorationActivity
		var userInfo = activity.userInfo ?? [AnyHashable: Any]()
		
		userInfo[UserInfoKey.windowState] = windowState()
		
		let articleState = articleViewController?.currentState
		userInfo[UserInfoKey.isShowingExtractedArticle] = articleState?.isShowingExtractedArticle ?? false
		userInfo[UserInfoKey.articleWindowScrollY] = articleState?.windowScrollY ?? 0

		activity.userInfo = userInfo
		return activity
	}
	
	var isRootSplitCollapsed: Bool {
		return rootSplitViewController.isCollapsed
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
	
	// At some point we should refactor the current Feed IndexPath out and only use the timeline feed
	private(set) var currentFeedIndexPath: IndexPath?

	var timelineIconImage: IconImage? {
		guard let timelineFeed = timelineFeed else {
			return nil
		}
		return IconImageCache.shared.imageForFeed(timelineFeed)
	}
	
	private var exceptionArticleFetcher: ArticleFetcher?
	private(set) var timelineFeed: Feed?
	
	var timelineMiddleIndexPath: IndexPath?
	
	private(set) var showFeedNames = ShowFeedName.none
	private(set) var showIcons = false

	var prevFeedIndexPath: IndexPath? {
		guard let indexPath = currentFeedIndexPath else {
			return nil
		}
		
		let prevIndexPath: IndexPath? = {
			if indexPath.row - 1 < 0 {
				for i in (0..<indexPath.section).reversed() {
					if shadowTable[i].feedNodes.count > 0 {
						return IndexPath(row: shadowTable[i].feedNodes.count - 1, section: i)
					}
				}
				return nil
			} else {
				return IndexPath(row: indexPath.row - 1, section: indexPath.section)
			}
		}()
		
		return prevIndexPath
	}
	
	var nextFeedIndexPath: IndexPath? {
		guard let indexPath = currentFeedIndexPath else {
			return nil
		}
		
		let nextIndexPath: IndexPath? = {
			if indexPath.row + 1 >= shadowTable[indexPath.section].feedNodes.count {
				for i in indexPath.section + 1..<shadowTable.count {
					if shadowTable[i].feedNodes.count > 0 {
						return IndexPath(row: 0, section: i)
					}
				}
				return nil
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

	private(set) var articles = ArticleArray() {
		didSet {
			timelineMiddleIndexPath = nil
			articleDictionaryNeedsUpdate = true
		}
	}

	private var articleDictionaryNeedsUpdate = true
	private var _idToArticleDictionary = [String: Article]()
	private var idToAticleDictionary: [String: Article] {
		if articleDictionaryNeedsUpdate {
			rebuildArticleDictionaries()
		}
		return _idToArticleDictionary
	}

	private var currentArticleRow: Int? {
		guard let article = currentArticle else { return nil }
		return articles.firstIndex(of: article)
	}

	var isTimelineUnreadAvailable: Bool {
		return timelineUnreadCount > 0
	}
	
	var isAnyUnreadAvailable: Bool {
		return appDelegate.unreadCount > 0
	}
	
	var timelineUnreadCount: Int = 0
	
	init(rootSplitViewController: RootSplitViewController) {
		self.rootSplitViewController = rootSplitViewController
		self.treeController = TreeController(delegate: treeControllerDelegate)

		super.init()

		self.masterFeedViewController = rootSplitViewController.viewController(for: .primary) as? MasterFeedViewController
		self.masterFeedViewController.coordinator = self
		if let navController = self.masterFeedViewController?.navigationController {
			navController.delegate = self
			configureNavigationController(navController)
		}

		self.masterTimelineViewController = rootSplitViewController.viewController(for: .supplementary) as? MasterTimelineViewController
		self.masterTimelineViewController?.coordinator = self
		if let navController = self.masterTimelineViewController?.navigationController {
			navController.delegate = self
			configureNavigationController(navController)
		}

		self.articleViewController = rootSplitViewController.viewController(for: .secondary) as? ArticleViewController
		self.articleViewController?.coordinator = self
		if let navController = self.articleViewController?.navigationController {
			configureNavigationController(navController)
		}

		for sectionNode in treeController.rootNode.childNodes {
			markExpanded(sectionNode)
			shadowTable.append((sectionID: "", feedNodes: [FeedNode]()))
		}
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidInitialize(_:)), name: .UnreadCountDidInitialize, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddAccount(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidDeleteAccount(_:)), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddFeed(_:)), name: .UserDidAddFeed, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(importDownloadedTheme(_:)), name: .didEndDownloadingTheme, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(themeDownloadDidFail(_:)), name: .didFailToImportThemeWithError, object: nil)
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
		selectFeed(indexPath: nil) {
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
				self.showAddWebFeed()
			}
		}
	}
	
	func handle(_ response: UNNotificationResponse) {
		let userInfo = response.notification.request.content.userInfo
		handleReadArticle(userInfo)
	}
	
	func resetFocus() {
		if currentArticle != nil {
			masterTimelineViewController?.focus()
		} else {
			masterFeedViewController?.focus()
		}
	}
	
	func selectFirstUnreadInAllUnread() {
		markExpanded(SmartFeedsController.shared)
		self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.unreadFeed) {
			self.selectFeed(SmartFeedsController.shared.unreadFeed) {
				self.selectFirstUnreadArticleInTimeline()
			}
		}
	}

	func showSearch() {
		selectFeed(indexPath: nil) {
			self.rootSplitViewController.show(.supplementary)
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
	}

	@objc func unreadCountDidChange(_ note: Notification) {
		// We will handle the filtering of unread feeds in unreadCountDidInitialize after they have all be calculated
		guard AccountManager.shared.isUnreadCountsInitialized else {
			return	
		}
		
		queueRebuildBackingStores()
	}

	@objc func statusesDidChange(_ note: Notification) {
		updateUnreadCount()
	}
	
	@objc func containerChildrenDidChange(_ note: Notification) {
		if timelineFetcherContainsAnyPseudoFeed() || timelineFetcherContainsAnyFolder() {
			fetchAndMergeArticlesAsync(animated: true) {
				self.masterTimelineViewController?.reinitializeArticles(resetScroll: false)
				self.rebuildBackingStores()
			}
		} else {
			rebuildBackingStores()
		}
	}
	
	@objc func batchUpdateDidPerform(_ notification: Notification) {
		rebuildBackingStores()
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		rebuildBackingStores()
	}

	@objc func accountStateDidChange(_ note: Notification) {
		if timelineFetcherContainsAnyPseudoFeed() {
			fetchAndMergeArticlesAsync(animated: true) {
				self.masterTimelineViewController?.reinitializeArticles(resetScroll: false)
				self.rebuildBackingStores()
			}
		} else {
			self.rebuildBackingStores()
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
			fetchAndMergeArticlesAsync(animated: true) {
				self.masterTimelineViewController?.reinitializeArticles(resetScroll: false)
				self.rebuildBackingStores(updateExpandedNodes: expandNewAccount)
			}
		} else {
			self.rebuildBackingStores(updateExpandedNodes: expandNewAccount)
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
			fetchAndMergeArticlesAsync(animated: true) {
				self.masterTimelineViewController?.reinitializeArticles(resetScroll: false)
				self.rebuildBackingStores(updateExpandedNodes: cleanupAccount)
			}
		} else {
			self.rebuildBackingStores(updateExpandedNodes: cleanupAccount)
		}
	}

	@objc func userDidAddFeed(_ notification: Notification) {
		guard let webFeed = notification.userInfo?[UserInfoKey.webFeed] as? WebFeed else {
			return
		}
		discloseWebFeed(webFeed, animations: [.scroll, .navigation])
	}
	
	@objc func userDefaultsDidChange(_ note: Notification) {
		self.sortDirection = AppDefaults.shared.timelineSortDirection
		self.groupByFeed = AppDefaults.shared.timelineGroupByFeed
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
	
	@objc func willEnterForeground(_ note: Notification) {
		// Don't interfere with any fetch requests that we may have initiated before the app was returned to the foreground.
		// For example if you select Next Unread from the Home Screen Quick actions, you can start a request before we are
		// in the foreground.
		if !fetchRequestQueue.isAnyCurrentRequest {
			queueFetchAndMergeArticles()
		}
	}
	
	@objc func importDownloadedTheme(_ note: Notification) {
		guard let userInfo = note.userInfo,
			let url = userInfo["url"] as? URL else {
			return
		}
		
		DispatchQueue.main.async {
			self.importTheme(filename: url.path)
		}
	}
	
	@objc func themeDownloadDidFail(_ note: Notification) {
		guard let userInfo = note.userInfo,
			  let error = userInfo["error"] as? Error else {
				  return
			  }
		DispatchQueue.main.async {
			self.rootSplitViewController.presentError(error, dismiss: nil)
		}
	}

	// MARK: API
	
	func suspend() {
		fetchAndMergeArticlesQueue.performCallsImmediately()
		rebuildBackingStoresQueue.performCallsImmediately()
		fetchRequestQueue.cancelAllRequests()
	}
	
	func cleanUp(conditional: Bool) {
		if isReadFeedsFiltered {
			rebuildBackingStores()
		}
		if isReadArticlesFiltered && (AppDefaults.shared.refreshClearsReadArticles || !conditional) {
			refreshTimeline(resetScroll: false)
		}
	}
	
	func toggleReadFeedsFilter() {
		if isReadFeedsFiltered {
			treeControllerDelegate.isReadFiltered = false
		} else {
			treeControllerDelegate.isReadFiltered = true
		}
		rebuildBackingStores()
		masterFeedViewController?.updateUI()
	}
	
	func toggleReadArticlesFilter() {
		guard let feedID = timelineFeed?.feedID else {
			return
		}

		if isReadArticlesFiltered {
			readFilterEnabledTable[feedID] = false
		} else {
			readFilterEnabledTable[feedID] = true
		}
		
		refreshTimeline(resetScroll: false)
	}

	func nodeFor(feedID: FeedIdentifier) -> Node? {
		return treeController.rootNode.descendantNode(where: { node in
			if let feed = node.representedObject as? Feed {
				return feed.feedID == feedID
			} else {
				return false
			}
		})
	}
	
	func numberOfSections() -> Int {
		return shadowTable.count
	}
	
	func numberOfRows(in section: Int) -> Int {
		return shadowTable[section].feedNodes.count
	}
	
	func nodeFor(_ indexPath: IndexPath) -> Node? {
		guard indexPath.section < shadowTable.count && indexPath.row < shadowTable[indexPath.section].feedNodes.count else {
			return nil
		}
		return shadowTable[indexPath.section].feedNodes[indexPath.row].node
	}
	
	func indexPathFor(_ node: Node) -> IndexPath? {
		for i in 0..<shadowTable.count {
			if let row = shadowTable[i].feedNodes.firstIndex(of: FeedNode(node)) {
				return IndexPath(row: row, section: i)
			}
		}
		return nil
	}
	
	func articleFor(_ articleID: String) -> Article? {
		return idToAticleDictionary[articleID]
	}
	
	func cappedIndexPath(_ indexPath: IndexPath) -> IndexPath {
		guard indexPath.section < shadowTable.count && indexPath.row < shadowTable[indexPath.section].feedNodes.count else {
			return IndexPath(row: shadowTable[shadowTable.count - 1].feedNodes.count - 1, section: shadowTable.count - 1)
		}
		return indexPath
	}
	
	func unreadCountFor(_ node: Node) -> Int {
		// The coordinator supplies the unread count for the currently selected feed
		if node.representedObject === timelineFeed as AnyObject {
			return timelineUnreadCount
		}
		if let unreadCountProvider = node.representedObject as? UnreadCountProvider {
			return unreadCountProvider.unreadCount
		}
		assertionFailure("This method should only be called for nodes that have an UnreadCountProvider as the represented object.")
		return 0
	}
	
	func refreshTimeline(resetScroll: Bool) {
		if let article = self.currentArticle, let account = article.account {
			exceptionArticleFetcher = SingleArticleFetcher(account: account, articleID: article.articleID)
		}
		fetchAndReplaceArticlesAsync(animated: true) {
			self.masterTimelineViewController?.reinitializeArticles(resetScroll: resetScroll)
		}
	}
	
	func isExpanded(_ containerID: ContainerIdentifier) -> Bool {
		return expandedTable.contains(containerID)
	}
		
	func isExpanded(_ containerIdentifiable: ContainerIdentifiable) -> Bool {
		if let containerID = containerIdentifiable.containerID {
			return isExpanded(containerID)
		}
		return false
	}
		
	func isExpanded(_ node: Node) -> Bool {
		if let containerIdentifiable = node.representedObject as? ContainerIdentifiable {
			return isExpanded(containerIdentifiable)
		}
		return false
	}
		
	func expand(_ containerID: ContainerIdentifier) {
		markExpanded(containerID)
		rebuildBackingStores()
	}
	
	/// This is a special function that expects the caller to change the disclosure arrow state outside this function.
	/// Failure to do so will get the Sidebar into an invalid state.
	func expand(_ node: Node) {
		guard let containerID = (node.representedObject as? ContainerIdentifiable)?.containerID else { return }
		lastExpandedTable.insert(containerID)
		expand(containerID)
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
		rebuildBackingStores()
	}
	
	func collapse(_ containerID: ContainerIdentifier) {
		unmarkExpanded(containerID)
		rebuildBackingStores()
		clearTimelineIfNoLongerAvailable()
	}
	
	/// This is a special function that expects the caller to change the disclosure arrow state outside this function.
	/// Failure to do so will get the Sidebar into an invalid state.
	func collapse(_ node: Node) {
		guard let containerID = (node.representedObject as? ContainerIdentifiable)?.containerID else { return }
		lastExpandedTable.remove(containerID)
		collapse(containerID)
	}
	
	func collapseAllFolders() {
		for sectionNode in treeController.rootNode.childNodes {
			for topLevelNode in sectionNode.childNodes {
				if topLevelNode.representedObject is Folder {
					unmarkExpanded(topLevelNode)
				}
			}
		}
		rebuildBackingStores()
		clearTimelineIfNoLongerAvailable()
	}
	
	func masterFeedIndexPathForCurrentTimeline() -> IndexPath? {
		guard let node = treeController.rootNode.descendantNodeRepresentingObject(timelineFeed as AnyObject) else {
			return nil
		}
		return indexPathFor(node)
	}
	
	func selectFeed(_ feed: Feed?, animations: Animations = [], deselectArticle: Bool = true, completion: (() -> Void)? = nil) {
		let indexPath: IndexPath? = {
			if let feed = feed, let indexPath = indexPathFor(feed as AnyObject) {
				return indexPath
			} else {
				return nil
			}
		}()
		selectFeed(indexPath: indexPath, animations: animations, deselectArticle: deselectArticle, completion: completion)
	}
	
	func selectFeed(indexPath: IndexPath?, animations: Animations = [], deselectArticle: Bool = true, completion: (() -> Void)? = nil) {
		guard indexPath != currentFeedIndexPath else {
			completion?()
			return
		}
		
		currentFeedIndexPath = indexPath
		masterFeedViewController.updateFeedSelection(animations: animations)

		if deselectArticle {
			selectArticle(nil)
		}

		if let ip = indexPath, let node = nodeFor(ip), let feed = node.representedObject as? Feed {
			
			self.activityManager.selecting(feed: feed)
			self.rootSplitViewController.show(.supplementary)
			setTimelineFeed(feed, animated: false) {
				if self.isReadFeedsFiltered {
					self.rebuildBackingStores()
				}
				completion?()
			}
			
		} else {
			
			setTimelineFeed(nil, animated: false) {
				if self.isReadFeedsFiltered {
					self.rebuildBackingStores()
				}
				self.activityManager.invalidateSelecting()
				self.rootSplitViewController.show(.primary)
				completion?()
			}
			
		}
		
	}
	
	func selectPrevFeed() {
		if let indexPath = prevFeedIndexPath {
			selectFeed(indexPath: indexPath, animations: [.navigation, .scroll])
		}
	}
	
	func selectNextFeed() {
		if let indexPath = nextFeedIndexPath {
			selectFeed(indexPath: indexPath, animations: [.navigation, .scroll])
		}
	}
	
	func selectTodayFeed(completion: (() -> Void)? = nil) {
		markExpanded(SmartFeedsController.shared)
		self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.todayFeed) {
			self.selectFeed(SmartFeedsController.shared.todayFeed, animations: [.navigation, .scroll], completion: completion)
		}
	}

	func selectAllUnreadFeed(completion: (() -> Void)? = nil) {
		markExpanded(SmartFeedsController.shared)
		self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.unreadFeed) {
			self.selectFeed(SmartFeedsController.shared.unreadFeed, animations: [.navigation, .scroll], completion: completion)
		}
	}

	func selectStarredFeed(completion: (() -> Void)? = nil) {
		markExpanded(SmartFeedsController.shared)
		self.ensureFeedIsAvailableToSelect(SmartFeedsController.shared.starredFeed) {
			self.selectFeed(SmartFeedsController.shared.starredFeed, animations: [.navigation, .scroll], completion: completion)
		}
	}

	func selectArticle(_ article: Article?, animations: Animations = [], isShowingExtractedArticle: Bool? = nil, articleWindowScrollY: Int? = nil) {
		guard article != currentArticle else { return }
		
		currentArticle = article
		activityManager.reading(feed: timelineFeed, article: article)
		
		if article == nil {
			rootSplitViewController.show(.supplementary)
			masterTimelineViewController?.updateArticleSelection(animations: animations)
			articleViewController?.article = nil
			return
		}
		
		rootSplitViewController.show(.secondary)
		
		// Mark article as read before navigating to it, so the read status does not flash unread/read on display
		markArticles(Set([article!]), statusKey: .read, flag: true)
		masterTimelineViewController?.updateArticleSelection(animations: animations)
		articleViewController?.article = article
		if let isShowingExtractedArticle = isShowingExtractedArticle, let articleWindowScrollY = articleWindowScrollY {
			articleViewController?.restoreScrollPosition = (isShowingExtractedArticle, articleWindowScrollY)
		}
	}
	
	func beginSearching() {
		isSearching = true
		preSearchTimelineFeed = timelineFeed
		savedSearchArticles = articles
		savedSearchArticleIds = Set(articles.map { $0.articleID })
		setTimelineFeed(nil, animated: true)
		selectArticle(nil)
	}

	func endSearching() {
		if let oldTimelineFeed = preSearchTimelineFeed {
			emptyTheTimeline()
			timelineFeed = oldTimelineFeed
			masterTimelineViewController?.reinitializeArticles(resetScroll: true)
			replaceArticles(with: savedSearchArticles!, animated: true)
		} else {
			setTimelineFeed(nil, animated: true)
		}
		
		lastSearchString = ""
		lastSearchScope = nil
		preSearchTimelineFeed = nil
		savedSearchArticleIds = nil
		savedSearchArticles = nil
		isSearching = false
		selectArticle(nil)
		masterTimelineViewController?.focus()
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
	
	func findPrevArticle(_ article: Article) -> Article? {
		guard let index = articles.firstIndex(of: article), index > 0 else {
			return nil
		}
		return articles[index - 1]
	}
	
	func findNextArticle(_ article: Article) -> Article? {
		guard let index = articles.firstIndex(of: article), index + 1 != articles.count else {
			return nil
		}
		return articles[index + 1]
	}
	
	func selectPrevArticle() {
		if let article = prevArticle {
			selectArticle(article, animations: [.navigation, .scroll])
		}
	}
	
	func selectNextArticle() {
		if let article = nextArticle {
			selectArticle(article, animations: [.navigation, .scroll])
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
			return
		}

		if self.isSearching {
			self.masterTimelineViewController?.hideSearch()
		}

		selectNextUnreadFeed() {
			self.selectNextUnreadArticleInTimeline()
		}

	}
	
	func scrollOrGoToNextUnread() {
		if articleViewController?.canScrollDown() ?? false {
			articleViewController?.scrollPageDown()
		} else {
			selectNextUnread()
		}
	}

	func scrollUp() {
		if articleViewController?.canScrollUp() ?? false {
			articleViewController?.scrollPageUp()
		}
	}
	
	func markAllAsRead(_ articles: [Article], completion: (() -> Void)? = nil) {
		markArticlesWithUndo(articles, statusKey: .read, flag: true, completion: completion)
	}
	
	func markAllAsReadInTimeline(completion: (() -> Void)? = nil) {
		markAllAsRead(articles) {
			self.rootSplitViewController.show(.primary)
			completion?()
		}
	}

	func canMarkAboveAsRead(for article: Article) -> Bool {
		let articlesAboveArray = articles.articlesAbove(article: article)
		return articlesAboveArray.canMarkAllAsRead()
	}

	func markAboveAsRead() {
		guard let currentArticle = currentArticle else {
			return
		}

		markAboveAsRead(currentArticle)
	}

	func markAboveAsRead(_ article: Article) {
		let articlesAboveArray = articles.articlesAbove(article: article)
		markAllAsRead(articlesAboveArray)
	}

	func canMarkBelowAsRead(for article: Article) -> Bool {
		let articleBelowArray = articles.articlesBelow(article: article)
		return articleBelowArray.canMarkAllAsRead()
	}

	func markBelowAsRead() {
		guard let currentArticle = currentArticle else {
			return
		}

		markBelowAsRead(currentArticle)
	}

	func markBelowAsRead(_ article: Article) {
		let articleBelowArray = articles.articlesBelow(article: article)
		markAllAsRead(articleBelowArray)
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
		guard !article.status.read || article.isAvailableToMarkUnread else { return }
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

	func timelineFeedIsEqualTo(_ feed: WebFeed) -> Bool {
		guard let timelineFeed = timelineFeed as? WebFeed else {
			return false
		}

		return timelineFeed == feed
	}

	func discloseWebFeed(_ webFeed: WebFeed, initialLoad: Bool = false, animations: Animations = [], completion: (() -> Void)? = nil) {
		if isSearching {
			masterTimelineViewController?.hideSearch()
		}
		
		guard let account = webFeed.account else {
			completion?()
			return
		}
		
		let parentFolder = account.sortedFolders?.first(where: { $0.objectIsChild(webFeed) })
		
		markExpanded(account)
		if let parentFolder = parentFolder {
			markExpanded(parentFolder)
		}
	
		if let webFeedFeedID = webFeed.feedID {
			self.treeControllerDelegate.addFilterException(webFeedFeedID)
		}
		if let parentFolderFeedID = parentFolder?.feedID {
			self.treeControllerDelegate.addFilterException(parentFolderFeedID)
		}

		rebuildBackingStores(initialLoad: initialLoad, completion:  {
			self.treeControllerDelegate.resetFilterExceptions()
			self.selectFeed(nil) {
				self.selectFeed(webFeed, animations: animations, completion: completion)
			}
		})
		
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
	
	func showSettings(scrollToArticlesSection: Bool = false) {
		let settingsNavController = UIStoryboard.settings.instantiateInitialViewController() as! UINavigationController
		let settingsViewController = settingsNavController.topViewController as! SettingsViewController
		settingsViewController.scrollToArticlesSection = scrollToArticlesSection
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
		let timelineWebFeed = timelineFeed as? WebFeed
		let articleFeed = currentArticle?.webFeed
		guard let feed = timelineWebFeed ?? articleFeed else {
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
	
	func showAddWebFeed(initialFeed: String? = nil, initialFeedName: String? = nil) {
		
		// Since Add Feed can be opened from anywhere with a keyboard shortcut, we have to deselect any currently selected feeds
		selectFeed(nil)

		let addNavViewController = UIStoryboard.add.instantiateViewController(withIdentifier: "AddWebFeedViewControllerNav") as! UINavigationController
		
		let addViewController = addNavViewController.topViewController as! AddFeedViewController
		addViewController.initialFeed = initialFeed
		addViewController.initialFeedName = initialFeedName
		
		addNavViewController.modalPresentationStyle = .formSheet
		addNavViewController.preferredContentSize = AddFeedViewController.preferredContentSizeForFormSheetDisplay
		masterFeedViewController.present(addNavViewController, animated: true)
	}
	
	func showAddRedditFeed() {
		let addNavViewController = UIStoryboard.redditAdd.instantiateInitialViewController() as! UINavigationController
		addNavViewController.modalPresentationStyle = .formSheet
		addNavViewController.preferredContentSize = AddFeedViewController.preferredContentSizeForFormSheetDisplay
		masterFeedViewController.present(addNavViewController, animated: true)
	}
	
	func showAddTwitterFeed() {
		let addNavViewController = UIStoryboard.twitterAdd.instantiateInitialViewController() as! UINavigationController
		addNavViewController.modalPresentationStyle = .formSheet
		addNavViewController.preferredContentSize = AddFeedViewController.preferredContentSizeForFormSheetDisplay
		masterFeedViewController.present(addNavViewController, animated: true)
	}
	
	func showAddFolder() {
		let addNavViewController = UIStoryboard.add.instantiateViewController(withIdentifier: "AddFolderViewControllerNav") as! UINavigationController
		addNavViewController.modalPresentationStyle = .formSheet
		addNavViewController.preferredContentSize = AddFolderViewController.preferredContentSizeForFormSheetDisplay
		masterFeedViewController.present(addNavViewController, animated: true)
	}
	
	func showFullScreenImage(image: UIImage, imageTitle: String?, transitioningDelegate: UIViewControllerTransitioningDelegate) {
		let imageVC = UIStoryboard.main.instantiateController(ofType: ImageViewController.self)
		imageVC.image = image
		imageVC.imageTitle = imageTitle
		imageVC.modalPresentationStyle = .currentContext
		imageVC.transitioningDelegate = transitioningDelegate
		rootSplitViewController.present(imageVC, animated: true)
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
		guard let url = article.preferredURL else { return }
		UIApplication.shared.open(url, options: [:])
	}

	func showBrowserForCurrentArticle() {
		guard let url = currentArticle?.preferredURL else { return }
		UIApplication.shared.open(url, options: [:])
	}
	
	func showInAppBrowser() {
		if currentArticle != nil {
			articleViewController?.openInAppBrowser()
		}
		else {
			masterFeedViewController.openInAppBrowser()
		}
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

	func toggleSidebar() {
		rootSplitViewController.preferredDisplayMode = rootSplitViewController.displayMode == .oneBesideSecondary ? .secondaryOnly : .oneBesideSecondary
	}
	
	func selectArticleInCurrentFeed(_ articleID: String, isShowingExtractedArticle: Bool? = nil, articleWindowScrollY: Int? = nil) {
		if let article = self.articles.first(where: { $0.articleID == articleID }) {
			self.selectArticle(article, isShowingExtractedArticle: isShowingExtractedArticle, articleWindowScrollY: articleWindowScrollY)
		}
	}
	
	func importTheme(filename: String) {
		do {
			try ArticleThemeImporter.importTheme(controller: rootSplitViewController, filename: filename)
		} catch {
			NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error" : error])
		}
		
	}
	
	/// This will dismiss the foremost view controller if the user
	/// has launched from an external action (i.e., a widget tap, or
	/// selecting an article via a notification).
	///
	/// The dismiss is only applicable if the view controller is a
	/// `SFSafariViewController` or `SettingsViewController`,
	/// otherwise, this function does nothing.
	func dismissIfLaunchingFromExternalAction() {
		guard let presentedController = masterFeedViewController.presentedViewController else { return }
		
		if presentedController.isKind(of: SFSafariViewController.self) {
			presentedController.dismiss(animated: true, completion: nil)
		}
		guard let settings = presentedController.children.first as? SettingsViewController else { return }
		settings.dismiss(animated: true, completion: nil)
	}
	
}

// MARK: UISplitViewControllerDelegate

extension SceneCoordinator: UISplitViewControllerDelegate {

	func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
		switch proposedTopColumn {
		case .supplementary:
			if currentFeedIndexPath != nil {
				return .supplementary
			} else {
				return .primary
			}
		case .secondary:
			if currentArticle != nil {
				return .secondary
			} else {
				if currentFeedIndexPath != nil {
					return .supplementary
				} else {
					return .primary
				}
			}
		default:
			return .primary
		}
	}
	
}

// MARK: UINavigationControllerDelegate

extension SceneCoordinator: UINavigationControllerDelegate {
	
	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		guard UIApplication.shared.applicationState != .background else {
			return
		}
		
		guard rootSplitViewController.isCollapsed else {
			return
		}

		defer {
			if let mainController = viewController as? MainControllerIdentifiable {
				lastMainControllerToAppear = mainController.mainControllerIdentifer
			} else if let mainController = (viewController as? UINavigationController)?.topViewController as? MainControllerIdentifiable {
				lastMainControllerToAppear = mainController.mainControllerIdentifer
			}
		}

		// If we are showing the Feeds and only the feeds start clearing stuff
		if viewController === masterFeedViewController && lastMainControllerToAppear == .masterTimeline {
			activityManager.invalidateCurrentActivities()
			selectFeed(nil, animations: [.scroll, .select, .navigation])
			return
		}

		// If we are using a phone and navigate away from the detail, clear up the article resources (including activity).
		// Don't clear it if we have pushed an ArticleViewController, but don't yet see it on the navigation stack.
		// This happens when we are going to the next unread and we need to grab another timeline to continue.  The
		// ArticleViewController will be pushed, but we will briefly show the Timeline.  Don't clear things out when that happens.
		if viewController === masterTimelineViewController && lastMainControllerToAppear == .article {
			selectArticle(nil)

			// Restore any bars hidden by the article controller
			showStatusBar()
			
			// We delay the showing of the navigation bars because it freaks out on iOS 15 with the new split view controller
			// if it is trying to show at the same time as the show timeline animation
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				navigationController.setNavigationBarHidden(false, animated: true)
			}
			navigationController.setToolbarHidden(false, animated: true)
			return
		}
	}

}

// MARK: Private

private extension SceneCoordinator {
	
	func configureNavigationController(_ navController: UINavigationController) {
		
		let scrollEdge = UINavigationBarAppearance()
		scrollEdge.configureWithOpaqueBackground()
		scrollEdge.shadowColor = nil
		scrollEdge.shadowImage = UIImage()
		
		let standard = UINavigationBarAppearance()
		standard.shadowColor = .opaqueSeparator
		standard.shadowImage = UIImage()
		
		navController.navigationBar.standardAppearance = standard
		navController.navigationBar.compactAppearance = standard
		navController.navigationBar.scrollEdgeAppearance = scrollEdge
		navController.navigationBar.compactScrollEdgeAppearance = scrollEdge
		
		navController.navigationBar.tintColor = AppAssets.primaryAccentColor
		
		let toolbarAppearance = UIToolbarAppearance()
		navController.toolbar.standardAppearance = toolbarAppearance
		navController.toolbar.compactAppearance = toolbarAppearance
		navController.toolbar.scrollEdgeAppearance = toolbarAppearance
		navController.toolbar.tintColor = AppAssets.primaryAccentColor
	}

	func markArticlesWithUndo(_ articles: [Article], statusKey: ArticleStatus.Key, flag: Bool, completion: (() -> Void)? = nil) {
		guard let undoManager = undoManager,
			  let markReadCommand = MarkStatusCommand(initialArticles: articles, statusKey: statusKey, flag: flag, undoManager: undoManager, completion: completion) else {
			completion?()
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
		timelineUnreadCount = count
		articleViewController?.currentUnreadCount = timelineUnreadCount
	}
	
	func rebuildArticleDictionaries() {
		var idDictionary = [String: Article]()

		articles.forEach { article in
			idDictionary[article.articleID] = article
		}

		_idToArticleDictionary = idDictionary
		articleDictionaryNeedsUpdate = false
	}
	
	func ensureFeedIsAvailableToSelect(_ feed: Feed, completion: @escaping () -> Void) {
		addToFilterExeptionsIfNecessary(feed)
		addShadowTableToFilterExceptions()
		
		rebuildBackingStores(completion:  {
			self.treeControllerDelegate.resetFilterExceptions()
			completion()
		})
	}

	func addToFilterExeptionsIfNecessary(_ feed: Feed?) {
		if isReadFeedsFiltered, let feedID = feed?.feedID {
			if feed is SmartFeed {
				treeControllerDelegate.addFilterException(feedID)
			} else if let folderFeed = feed as? Folder {
				if folderFeed.account?.existingFolder(withID: folderFeed.folderID) != nil {
					treeControllerDelegate.addFilterException(feedID)
				}
			} else if let webFeed = feed as? WebFeed {
				if webFeed.account?.existingWebFeed(withWebFeedID: webFeed.webFeedID) != nil {
					treeControllerDelegate.addFilterException(feedID)
					addParentFolderToFilterExceptions(webFeed)
				}
			}
		}
	}
	
	func addParentFolderToFilterExceptions(_ feed: Feed) {
		guard let node = treeController.rootNode.descendantNodeRepresentingObject(feed as AnyObject),
			let folder = node.parent?.representedObject as? Folder,
			let folderFeedID = folder.feedID else {
				return
		}
		
		treeControllerDelegate.addFilterException(folderFeedID)
	}
	
	func addShadowTableToFilterExceptions() {
		for section in shadowTable {
			for feedNode in section.feedNodes {
				if let feed = feedNode.node.representedObject as? Feed, let feedID = feed.feedID {
					treeControllerDelegate.addFilterException(feedID)
				}
			}
		}
	}
	
	func queueRebuildBackingStores() {
		rebuildBackingStoresQueue.add(self, #selector(rebuildBackingStoresWithDefaults))
	}

	@objc func rebuildBackingStoresWithDefaults() {
		rebuildBackingStores()
	}
	
	func rebuildBackingStores(initialLoad: Bool = false, updateExpandedNodes: (() -> Void)? = nil, completion: (() -> Void)? = nil) {
		if !BatchUpdate.shared.isPerforming {
			addToFilterExeptionsIfNecessary(timelineFeed)
			treeController.rebuild()
			treeControllerDelegate.resetFilterExceptions()
			
			updateExpandedNodes?()
			let changes = rebuildShadowTable()
			masterFeedViewController.reloadFeeds(initialLoad: initialLoad, changes: changes, completion: completion)
		}
	}
	
	func rebuildShadowTable() -> ShadowTableChanges {
		var newShadowTable = [(sectionID: String, feedNodes: [FeedNode])]()

		for i in 0..<treeController.rootNode.numberOfChildNodes {
			
			var feedNodes = [FeedNode]()
			let sectionNode = treeController.rootNode.childAtIndex(i)!
			
			if isExpanded(sectionNode) {
				for node in sectionNode.childNodes {
					feedNodes.append(FeedNode(node))
					if isExpanded(node) {
						for child in node.childNodes {
							feedNodes.append(FeedNode(child))
						}
					}
				}
			}
			
			let sectionID = (sectionNode.representedObject as? Account)?.accountID ?? ""
			newShadowTable.append((sectionID: sectionID, feedNodes: feedNodes))
		}
		
		// If we have a current Feed IndexPath it is no longer valid and needs reset.
		if currentFeedIndexPath != nil {
			currentFeedIndexPath = indexPathFor(timelineFeed as AnyObject)
		}
		
		// Compute the differences in the shadow table rows and the expanded table entries
		var changes = [ShadowTableChanges.RowChanges]()
		let expandedTableDifference = lastExpandedTable.symmetricDifference(expandedTable)

		for (section, newSectionRows) in newShadowTable.enumerated() {
			var moves = Set<ShadowTableChanges.Move>()
			var inserts = Set<Int>()
			var deletes = Set<Int>()
			
			let oldFeedNodes = shadowTable.first(where: { $0.sectionID == newSectionRows.sectionID })?.feedNodes ?? [FeedNode]()
			
			let diff = newSectionRows.feedNodes.difference(from: oldFeedNodes).inferringMoves()
			for change in diff {
				switch change {
				case .insert(let offset, _, let associated):
					if let associated = associated {
						moves.insert(ShadowTableChanges.Move(associated, offset))
					} else {
						inserts.insert(offset)
					}
				case .remove(let offset, _, let associated):
					if let associated = associated {
						moves.insert(ShadowTableChanges.Move(offset, associated))
					} else {
						deletes.insert(offset)
					}
				}
			}
			
			// We need to reload the difference in expanded rows to get the disclosure arrows correct when programmatically changing their state
			var reloads = Set<Int>()
			
			for (index, newFeedNode) in newSectionRows.feedNodes.enumerated() {
				if let newFeedNodeContainerID = (newFeedNode.node.representedObject as? Container)?.containerID {
					if expandedTableDifference.contains(newFeedNodeContainerID) {
						reloads.insert(index)
					}
				}
			}
			
			changes.append(ShadowTableChanges.RowChanges(section: section, deletes: deletes, inserts: inserts, reloads: reloads, moves: moves))
		}

		lastExpandedTable = expandedTable
		
		// Compute the difference in the shadow table sections
		var moves = Set<ShadowTableChanges.Move>()
		var inserts = Set<Int>()
		var deletes = Set<Int>()
		
		let oldSections = shadowTable.map { $0.sectionID }
		let newSections = newShadowTable.map { $0.sectionID }
		let diff = newSections.difference(from: oldSections).inferringMoves()
		for change in diff {
			switch change {
			case .insert(let offset, _, let associated):
				if let associated = associated {
					moves.insert(ShadowTableChanges.Move(associated, offset))
				} else {
					inserts.insert(offset)
				}
			case .remove(let offset, _, let associated):
				if let associated = associated {
					moves.insert(ShadowTableChanges.Move(offset, associated))
				} else {
					deletes.insert(offset)
				}
			}
		}

		shadowTable = newShadowTable
		
		return ShadowTableChanges(deletes: deletes, inserts: inserts, moves: moves, rowChanges: changes)
	}
	
	func shadowTableContains(_ feed: Feed) -> Bool {
		for section in shadowTable {
			for feedNode in section.feedNodes {
				if let nodeFeed = feedNode.node.representedObject as? Feed, nodeFeed.feedID == feed.feedID {
					return true
				}
			}
		}
		return false
	}
	
	func clearTimelineIfNoLongerAvailable() {
		if let feed = timelineFeed, !shadowTableContains(feed) {
			selectFeed(nil, deselectArticle: true)
		}
	}

	func indexPathFor(_ object: AnyObject) -> IndexPath? {
		guard let node = treeController.rootNode.descendantNodeRepresentingObject(object) else {
			return nil
		}
		return indexPathFor(node)
	}
	
	func setTimelineFeed(_ feed: Feed?, animated: Bool, completion: (() -> Void)? = nil) {
		timelineFeed = feed
		
		fetchAndReplaceArticlesAsync(animated: animated) {
			self.masterTimelineViewController?.reinitializeArticles(resetScroll: true)
			completion?()
		}
	}
	
	func updateShowNamesAndIcons() {
		
		if timelineFeed is WebFeed {
			showFeedNames = {
				for article in articles {
					if !article.byline().isEmpty {
						return .byline
					}
				}
				return .none
			}()
		} else {
			showFeedNames = .feed
		}

		if showFeedNames == .feed {
			self.showIcons = true
			return
		}
		
		if showFeedNames == .none {
			self.showIcons = false
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
	
	func markExpanded(_ containerID: ContainerIdentifier) {
		expandedTable.insert(containerID)
	}

	func markExpanded(_ containerIdentifiable: ContainerIdentifiable) {
		if let containerID = containerIdentifiable.containerID {
			markExpanded(containerID)
		}
	}
	
	func markExpanded(_ node: Node) {
		if let containerIdentifiable = node.representedObject as? ContainerIdentifiable {
			markExpanded(containerIdentifiable)
		}
	}
	
	func unmarkExpanded(_ containerID: ContainerIdentifier) {
		expandedTable.remove(containerID)
	}

	func unmarkExpanded(_ containerIdentifiable: ContainerIdentifiable) {
		if let containerID = containerIdentifiable.containerID {
			unmarkExpanded(containerID)
		}
	}

	func unmarkExpanded(_ node: Node) {
		if let containerIdentifiable = node.representedObject as? ContainerIdentifiable {
			unmarkExpanded(containerIdentifiable)
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
					return IndexPath(row: shadowTable[shadowTable.count - 1].feedNodes.count - 1, section: shadowTable.count - 1)
				} else {
					return IndexPath(row: shadowTable[indexPath.section - 1].feedNodes.count - 1, section: indexPath.section - 1)
				}
			} else {
				return IndexPath(row: indexPath.row - 1, section: indexPath.section)
			}
		}()
		
		if selectPrevUnreadFeedFetcher(startingWith: nextIndexPath) {
			return
		}
		let maxIndexPath = IndexPath(row: shadowTable[shadowTable.count - 1].feedNodes.count - 1, section: shadowTable.count - 1)
		selectPrevUnreadFeedFetcher(startingWith: maxIndexPath)
		
	}
	
	@discardableResult
	func selectPrevUnreadFeedFetcher(startingWith indexPath: IndexPath) -> Bool {
		
		for i in (0...indexPath.section).reversed() {
			
			let startingRow: Int = {
				if indexPath.section == i {
					return indexPath.row
				} else {
					return shadowTable[i].feedNodes.count - 1
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
					selectFeed(indexPath: prevIndexPath, animations: [.scroll, .navigation])
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
				selectArticle(article, animations: [.scroll, .navigation])
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
			if indexPath.row + 1 >= shadowTable[indexPath.section].feedNodes.count {
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

			for j in startingRow..<shadowTable[i].feedNodes.count {

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
					selectFeed(indexPath: nextIndexPath, animations: [.scroll, .navigation], deselectArticle: false) {
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
		fetchAndMergeArticlesQueue.add(self, #selector(fetchAndMergeArticlesAsync))
	}

	@objc func fetchAndMergeArticlesAsync() {
		fetchAndMergeArticlesAsync(animated: true) {
			self.masterTimelineViewController?.reinitializeArticles(resetScroll: false)
			self.masterTimelineViewController?.restoreSelectionIfNecessary(adjustScroll: false)
		}
	}
	
	func fetchAndMergeArticlesAsync(animated: Bool = true, completion: (() -> Void)? = nil) {
		
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
				if article.account?.existingWebFeed(withWebFeedID: article.webFeedID) == nil {
					updatedArticles.remove(article)
				}
			}

			strongSelf.replaceArticles(with: updatedArticles, animated: animated)
			completion?()
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

	func fetchUnsortedArticlesAsync(for representedObjects: [Any], completion: @escaping ArticleSetBlock) {
		// The callback will *not* be called if the fetch is no longer relevant — that is,
		// if it’s been superseded by a newer fetch, or the timeline was emptied, etc., it won’t get called.
		precondition(Thread.isMainThread)
		cancelPendingAsyncFetches()
		
		let fetchers = representedObjects.compactMap { $0 as? ArticleFetcher }
		let fetchOperation = FetchRequestOperation(id: fetchSerialNumber, readFilterEnabledTable: readFilterEnabledTable, fetchers: fetchers) { [weak self] (articles, operation) in
			precondition(Thread.isMainThread)
			guard !operation.isCanceled, let strongSelf = self, operation.id == strongSelf.fetchSerialNumber else {
				return
			}
			completion(articles)
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
		
		switch feedIdentifier {
		
		case .smartFeed:
			guard let smartFeed = SmartFeedsController.shared.find(by: feedIdentifier) else { return }

			markExpanded(SmartFeedsController.shared)
			rebuildBackingStores(initialLoad: true, completion:  {
				self.treeControllerDelegate.resetFilterExceptions()
				if let indexPath = self.indexPathFor(smartFeed) {
					self.selectFeed(indexPath: indexPath) {
						self.masterFeedViewController.focus()
					}
				}
			})
		
		case .script:
			break
		
		case .folder(let accountID, let folderName):
			guard let accountNode = self.findAccountNode(accountID: accountID),
				let account = accountNode.representedObject as? Account else {
				return
			}

			markExpanded(account)
			
			rebuildBackingStores(initialLoad: true, completion:  {
				self.treeControllerDelegate.resetFilterExceptions()
				
				if let folderNode = self.findFolderNode(folderName: folderName, beginningAt: accountNode), let indexPath = self.indexPathFor(folderNode) {
					self.selectFeed(indexPath: indexPath) {
						self.masterFeedViewController.focus()
					}
				}
			})
		
		case .webFeed(let accountID, let webFeedID):
			guard let accountNode = findAccountNode(accountID: accountID),
				let account = accountNode.representedObject as? Account,
				let webFeed = account.existingWebFeed(withWebFeedID: webFeedID) else {
				return
			}
			
			self.discloseWebFeed(webFeed, initialLoad: true) {
				self.masterFeedViewController.focus()
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
		
		guard let webFeed = account.existingWebFeed(withWebFeedID: webFeedID) else {
			return
		}
		
		discloseWebFeed(webFeed) {
			self.selectArticleInCurrentFeed(articleID)
		}
	}
	
	func restoreFeedSelection(_ userInfo: [AnyHashable : Any], accountID: String, webFeedID: String, articleID: String) -> Bool {
		guard let feedIdentifierUserInfo = userInfo[UserInfoKey.feedIdentifier] as? [AnyHashable : AnyHashable],
			  let feedIdentifier = FeedIdentifier(userInfo: feedIdentifierUserInfo),
			  let isShowingExtractedArticle = userInfo[UserInfoKey.isShowingExtractedArticle] as? Bool,
			  let articleWindowScrollY = userInfo[UserInfoKey.articleWindowScrollY] as? Int else {
				  return false
			  }

		switch feedIdentifier {

		case .script:
			return false

		case .smartFeed, .folder:
			let found = selectFeedAndArticle(feedIdentifier: feedIdentifier, articleID: articleID, isShowingExtractedArticle: isShowingExtractedArticle, articleWindowScrollY: articleWindowScrollY)
			if found {
				treeControllerDelegate.addFilterException(feedIdentifier)
			}
			return found
		
		case .webFeed:
			let found = selectFeedAndArticle(feedIdentifier: feedIdentifier, articleID: articleID, isShowingExtractedArticle: isShowingExtractedArticle, articleWindowScrollY: articleWindowScrollY)
			if found {
				treeControllerDelegate.addFilterException(feedIdentifier)
				if let webFeedNode = nodeFor(feedID: feedIdentifier), let folder = webFeedNode.parent?.representedObject as? Folder, let folderFeedID = folder.feedID {
					treeControllerDelegate.addFilterException(folderFeedID)
				}
			}
			return found
			
		}
		
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
	
	func selectFeedAndArticle(feedIdentifier: FeedIdentifier, articleID: String, isShowingExtractedArticle: Bool, articleWindowScrollY: Int) -> Bool {
		guard let feedNode = nodeFor(feedID: feedIdentifier), let feedIndexPath = indexPathFor(feedNode) else { return false }
		
		selectFeed(indexPath: feedIndexPath) {
			self.selectArticleInCurrentFeed(articleID, isShowingExtractedArticle: isShowingExtractedArticle, articleWindowScrollY: articleWindowScrollY)
		}
		
		return true
	}
	
}
