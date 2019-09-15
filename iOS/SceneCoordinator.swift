//
//  NavigationModelController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import SwiftUI
import Account
import Articles
import RSCore
import RSTree

enum SearchScope: Int {
	case timeline = 0
	case global = 1
}

class SceneCoordinator: NSObject, UndoableCommandRunner, UnreadCountProvider {
	
	var undoableCommands = [UndoableCommand]()
	var undoManager: UndoManager? {
		return rootSplitViewController.undoManager
	}
	
	private var activityManager = ActivityManager()
	
	private var rootSplitViewController: RootSplitViewController!
	private var masterNavigationController: UINavigationController!
	private var masterFeedViewController: MasterFeedViewController!
	private var masterTimelineViewController: MasterTimelineViewController?
	
	private var subSplitViewController: UISplitViewController? {
		return rootSplitViewController.children.last as? UISplitViewController
	}
	
	private var detailViewController: DetailViewController? {
		if let detail = masterNavigationController.viewControllers.last as? DetailViewController {
			return detail
		}
		if let subSplit = subSplitViewController {
			if let navController = subSplit.viewControllers.last as? UINavigationController {
				return navController.topViewController as? DetailViewController
			}
		} else {
			if let navController = rootSplitViewController.viewControllers.last as? UINavigationController {
				return navController.topViewController as? DetailViewController
			}
		}
		return nil
	}
	
	private let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5)
	private var fetchSerialNumber = 0
	private let fetchRequestQueue = FetchRequestQueue()
	
	private var animatingChanges = false
	private var shadowTable = [[Node]]()
	private var lastSearchString = ""
	private var lastSearchScope: SearchScope? = nil
	private var isSearching: Bool = false
	private var searchArticleIds: Set<String>? = nil
	
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

	private let treeControllerDelegate = FeedTreeControllerDelegate()
	private lazy var treeController: TreeController = {
		return TreeController(delegate: treeControllerDelegate)
	}()
	
	var stateRestorationActivity: NSUserActivity? {
		return activityManager.stateRestorationActivity
	}
	
	var isRootSplitCollapsed: Bool {
		return rootSplitViewController.isCollapsed
	}
	
	var isThreePanelMode: Bool {
		return subSplitViewController != nil
	}
	
	var rootNode: Node {
		return treeController.rootNode
	}
	
	private(set) var currentFeedIndexPath: IndexPath?
	
	var timelineName: String? {
		return (timelineFetcher as? DisplayNameProvider)?.nameForDisplay
	}
	
	var timelineFetcher: ArticleFetcher? {
		didSet {

			if timelineFetcher is Feed {
				showFeedNames = false
			} else {
				showFeedNames = true
			}

			if isSearching {
				fetchAndReplaceArticlesAsync {
					self.masterTimelineViewController?.reinitializeArticles()
				}
			} else {
				fetchAndReplaceArticlesSync()
				masterTimelineViewController?.reinitializeArticles()
			}

		}
	}
	
	private(set) var showFeedNames = false
	private(set) var showAvatars = false

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
		if let unreadProvider = timelineFetcher as? UnreadCountProvider {
			return unreadProvider.unreadCount > 0
		}
		return false
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
		super.init()
		
		for section in treeController.rootNode.childNodes {
			section.isExpanded = true
			shadowTable.append([Node]())
		}
		
		rebuildShadowTable()
		
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddAccount(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidDeleteAccount(_:)), name: .UserDidDeleteAccount, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
		
		// Force lazy initialization of the web view provider so that it can warm up the queue of prepared web views
		let _ = DetailViewControllerWebViewProvider.shared
	}
	
	func start(for size: CGSize) -> UIViewController {
		rootSplitViewController = RootSplitViewController()
		rootSplitViewController.coordinator = self
		rootSplitViewController.preferredDisplayMode = .allVisible
		rootSplitViewController.viewControllers = [ThemedNavigationController.template()]
		rootSplitViewController.delegate = self
		
		masterNavigationController = (rootSplitViewController.viewControllers.first as! UINavigationController)
		masterNavigationController.delegate = self
		
		masterFeedViewController = UIStoryboard.main.instantiateController(ofType: MasterFeedViewController.self)
		masterFeedViewController.coordinator = self
		masterNavigationController.pushViewController(masterFeedViewController, animated: false)
		
		let noSelectionController = fullyWrappedSystemMesssageController(showButton: true)
		rootSplitViewController.showDetailViewController(noSelectionController, sender: self)

		configureThreePanelMode(for: size)
		
		return rootSplitViewController
	}
	
	func handle(_ activity: NSUserActivity) {
		selectFeed(nil)
		
		guard let activityType = ActivityType(rawValue: activity.activityType) else { return }
		switch activityType {
		case .selectToday:
			handleSelectToday()
		case .selectAllUnread:
			handleSelectAllUnread()
		case .selectStarred:
			handleSelectStarred()
		case .selectFolder:
			handleSelectFolder(activity)
		case .selectFeed:
			handleSelectFeed(activity)
		case .nextUnread:
			selectFirstUnreadInAllUnread()
		case .readArticle:
			handleReadArticle(activity)
		}
	}
	
	func configureThreePanelMode(for size: CGSize) {
		guard rootSplitViewController.traitCollection.userInterfaceIdiom == .pad && !rootSplitViewController.isCollapsed else {
			return
		}
		if size.width > size.height {
			if !isThreePanelMode {
				transitionToThreePanelMode()
			}
		} else {
			if isThreePanelMode {
				transitionFromThreePanelMode()
			}
		}
	}
	
	func selectFirstUnreadInAllUnread() {
		selectFeed(IndexPath(row: 1, section: 0))
		selectFirstUnreadArticleInTimeline()
	}

	func showSearch() {
		selectFeed(nil)
		installTimelineControllerIfNecessary(animated: false)
		DispatchQueue.main.asyncAfter(deadline: .now()) {
			self.masterTimelineViewController!.showSearchAll()
		}
	}
	
	// MARK: Notifications
	
	@objc func statusesDidChange(_ note: Notification) {
		updateUnreadCount()
	}
	
	@objc func containerChildrenDidChange(_ note: Notification) {
		if timelineFetcherContainsAnyPseudoFeed() || timelineFetcherContainsAnyFolder() {
			fetchAndReplaceArticlesAsync() {}
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
		if timelineFetcherContainsAnyPseudoFeed() {
			fetchAndReplaceArticlesSync()
		}
		
		guard let account = note.userInfo?[Account.UserInfoKey.account] as? Account else {
			assertionFailure()
			return
		}
		
		rebuildBackingStores() {
			// If we are activating an account, then automatically expand it
			if account.isActive, let node = self.treeController.rootNode.childNodeRepresentingObject(account) {
				node.isExpanded = true
			}
		}
	}
	
	@objc func userDidAddAccount(_ note: Notification) {
		if timelineFetcherContainsAnyPseudoFeed() {
			fetchAndReplaceArticlesSync()
		}
		
		rebuildBackingStores() {
			// Automatically expand any new accounts
			if let account = note.userInfo?[Account.UserInfoKey.account] as? Account,
				let node = self.treeController.rootNode.childNodeRepresentingObject(account) {
				node.isExpanded = true
			}
		}
	}

	@objc func userDidDeleteAccount(_ note: Notification) {
		if timelineFetcherContainsAnyPseudoFeed() {
			fetchAndReplaceArticlesSync()
		}
		rebuildBackingStores()
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		self.sortDirection = AppDefaults.timelineSortDirection
		self.groupByFeed = AppDefaults.timelineGroupByFeed
	}
	
	@objc func accountDidDownloadArticles(_ note: Notification) {
		guard let feeds = note.userInfo?[Account.UserInfoKey.feeds] as? Set<Feed> else {
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
		
	func expand(_ node: Node) {
		node.isExpanded = true
		animatingChanges = true
		rebuildShadowTable()
		animatingChanges = false
	}
	
	func expandAllSectionsAndFolders() {
		for sectionNode in treeController.rootNode.childNodes {
			sectionNode.isExpanded = true
			for topLevelNode in sectionNode.childNodes {
				if topLevelNode.representedObject is Folder {
					topLevelNode.isExpanded = true
				}
			}
		}
		animatingChanges = true
		rebuildShadowTable()
		animatingChanges = false
	}
	
	func collapse(_ node: Node) {
		node.isExpanded = false
		animatingChanges = true
		rebuildShadowTable()
		animatingChanges = false
	}
	
	func collapseAllFolders() {
		for sectionNode in treeController.rootNode.childNodes {
			sectionNode.isExpanded = true
			for topLevelNode in sectionNode.childNodes {
				if topLevelNode.representedObject is Folder {
					topLevelNode.isExpanded = true
				}
			}
		}
		animatingChanges = true
		rebuildShadowTable()
		animatingChanges = false
	}
	
	func masterFeedIndexPathForCurrentTimeline() -> IndexPath? {
		guard let node = treeController.rootNode.descendantNodeRepresentingObject(timelineFetcher as AnyObject) else {
			return nil
		}
		return indexPathFor(node)
	}
	
	func selectFeed(_ indexPath: IndexPath?, automated: Bool = true) {
		guard indexPath != currentFeedIndexPath else { return 	}
		
		selectArticle(nil)
		currentFeedIndexPath = indexPath

		masterFeedViewController.updateFeedSelection()

		if let ip = indexPath, let node = nodeFor(ip), let fetcher = node.representedObject as? ArticleFetcher {
			timelineFetcher = fetcher
			updateSelectingActivity(with: node)
			installTimelineControllerIfNecessary(animated: !automated)
		} else {
			timelineFetcher = nil
			activityManager.invalidateSelecting()
			if rootSplitViewController.isCollapsed && navControllerForTimeline().viewControllers.last is MasterTimelineViewController {
				navControllerForTimeline().popViewController(animated: !automated)
			}
		}
		
	}
	
	func selectPrevFeed() {
		if let indexPath = prevFeedIndexPath {
			selectFeed(indexPath)
		}
	}
	
	func selectNextFeed() {
		if let indexPath = nextFeedIndexPath {
			selectFeed(indexPath)
		}
	}
	
	func selectTodayFeed() {
		masterFeedViewController?.ensureSectionIsExpanded(0) {
			self.selectFeed(IndexPath(row: 0, section: 0))
		}
	}

	func selectAllUnreadFeed() {
		masterFeedViewController?.ensureSectionIsExpanded(0) {
			self.selectFeed(IndexPath(row: 1, section: 0))
		}
	}

	func selectStarredFeed() {
		masterFeedViewController?.ensureSectionIsExpanded(0) {
			self.selectFeed(IndexPath(row: 2, section: 0))
		}
	}

	func selectArticle(_ article: Article?, automated: Bool = true) {
		guard article != currentArticle else { return }
		
		currentArticle = article
		activityManager.reading(currentArticle)
		
		if article == nil {
			if rootSplitViewController.isCollapsed {
				if masterNavigationController.children.last is DetailViewController {
					masterNavigationController.popViewController(animated: !automated)
				}
			} else {
				let systemMessageViewController = UIStoryboard.main.instantiateController(ofType: SystemMessageViewController.self)
				installDetailController(systemMessageViewController, automated: automated)
			}
			masterTimelineViewController?.updateArticleSelection(animate: !automated)
			return
		}
		
		if detailViewController == nil {
			let detailViewController = UIStoryboard.main.instantiateController(ofType: DetailViewController.self)
			detailViewController.coordinator = self
			installDetailController(detailViewController, automated: automated)
		}
		
		if automated {
			masterTimelineViewController?.updateArticleSelection(animate: false)
		}
		
		detailViewController?.updateArticleSelection()
		
		if let article = currentArticle {
			markArticles(Set([article]), statusKey: .read, flag: true)
		}
	}
	
	func beginSearching() {
		isSearching = true
		searchArticleIds = Set(articles.map { $0.articleID })
		timelineFetcher = nil
	}

	func endSearching() {
		isSearching = false
		lastSearchString = ""
		lastSearchScope = nil
		searchArticleIds = nil
		
		if let ip = currentFeedIndexPath, let node = nodeFor(ip), let fetcher = node.representedObject as? ArticleFetcher {
			timelineFetcher = fetcher
		} else {
			timelineFetcher = nil
		}
		
		selectArticle(nil)
	}
	
	func searchArticles(_ searchString: String, _ searchScope: SearchScope) {
		
		guard isSearching else { return }
		
		if searchString.count < 3 {
			timelineFetcher = nil
			return
		}
		
		if searchString != lastSearchString || searchScope != lastSearchScope {
			
			switch searchScope {
			case .global:
				timelineFetcher = SmartFeed(delegate: SearchFeedDelegate(searchString: searchString))
			case .timeline:
				timelineFetcher = SmartFeed(delegate: SearchTimelineFeedDelegate(searchString: searchString, articleIDs: searchArticleIds!))
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
		
		selectNextUnreadFeedFetcher()
		if selectNextUnreadArticleInTimeline() {
			activityManager.selectingNextUnread()
		}

	}
	
	func scrollOrGoToNextUnread() {
		if detailViewController?.canScrollDown() ?? false {
			detailViewController?.scrollPageDown()
		} else {
			selectNextUnread()
		}
	}
	
	func markAllAsRead(_ articles: [Article]) {
		guard let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: articles, markingRead: true, undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}
	
	func markAllAsRead() {
		let accounts = AccountManager.shared.activeAccounts
		var articles = Set<Article>()
		accounts.forEach { account in
			articles.formUnion(account.fetchArticles(.unread))
		}
		markAllAsRead(Array(articles))
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
			markArticles(Set([article]), statusKey: .read, flag: true)
		}
	}
	
	func markAsUnreadForCurrentArticle() {
		if let article = currentArticle {
			markArticles(Set([article]), statusKey: .read, flag: false)
		}
	}
	
	func toggleReadForCurrentArticle() {
		if let article = currentArticle {
			markArticles(Set([article]), statusKey: .read, flag: !article.status.read)
		}
	}
	
	func toggleRead(_ article: Article) {
		guard let undoManager = undoManager,
			let markReadCommand = MarkStatusCommand(initialArticles: [article], markingRead: !article.status.read, undoManager: undoManager) else {
				return
		}
		runCommand(markReadCommand)
	}

	func toggleStarredForCurrentArticle() {
		if let article = currentArticle {
			markArticles(Set([article]), statusKey: .starred, flag: !article.status.starred)
		}
	}
	
	func toggleStar(_ article: Article) {
		guard let undoManager = undoManager,
			let markReadCommand = MarkStatusCommand(initialArticles: [article], markingStarred: !article.status.starred, undoManager: undoManager) else {
				return
		}
		runCommand(markReadCommand)
	}

	func discloseFeed(_ feed: Feed, completion: (() -> Void)? = nil) {
		masterFeedViewController.discloseFeed(feed) {
			completion?()
		}
	}
	
	func showSettings() {
		rootSplitViewController.present(style: .formSheet) {
			SettingsView(viewModel: SettingsView.ViewModel()).environment(\.sceneCoordinator, self)
		}
	}
	
	func showAdd(_ type: AddControllerType, initialFeed: String? = nil, initialFeedName: String? = nil) {
		selectFeed(nil)

		let addViewController = UIStoryboard.add.instantiateInitialViewController() as! UINavigationController
		
		let containerController = addViewController.topViewController as! AddContainerViewController
		containerController.initialControllerType = type
		containerController.initialFeed = initialFeed
		containerController.initialFeedName = initialFeedName
		
		addViewController.modalPresentationStyle = .formSheet
		addViewController.preferredContentSize = AddContainerViewController.preferredContentSizeForFormSheetDisplay
		masterFeedViewController.present(addViewController, animated: true)
	}
	
	func homePageURLForFeed(_ indexPath: IndexPath) -> URL? {
		guard let node = nodeFor(indexPath),
			let feed = node.representedObject as? Feed,
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
		detailViewController?.focus()
	}
	
}

// MARK: UISplitViewControllerDelegate

extension SceneCoordinator: UISplitViewControllerDelegate {
	
	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
	
		// Check to see if the system is currently configured for three panel mode
		if let subSplit = secondaryViewController as? UISplitViewController {

			// Take the timeline controller out of the subsplit and throw it on the master navigation stack
			if let masterTimelineNav = subSplit.viewControllers.first as? UINavigationController, let masterTimeline = masterTimelineNav.topViewController {
				masterNavigationController.pushViewController(masterTimeline, animated: false)
			}

			// Take the detail view (ignoring system message controllers) and put it on the master navigation stack
			if let detailNav = subSplit.viewControllers.last as? UINavigationController, let detail = detailNav.topViewController as? DetailViewController {
				masterNavigationController.pushViewController(detail, animated: false)
			}

		} else {
			
			// If the timeline controller has been initialized and only the feeds controller is on the stack, we add the timeline controller
			if let timeline = masterTimelineViewController, masterNavigationController.viewControllers.count == 1 {
				masterNavigationController.pushViewController(timeline, animated: false)
			}
			
			// Take the detail view (ignoring system message controllers) and put it on the master navigation stack
			if let detailNav = secondaryViewController as? UINavigationController, let detail = detailNav.topViewController as? DetailViewController {
				// I have no idea why, I have to wire up the left bar button item for this, but not when I am transitioning from three panel mode
				detail.navigationItem.leftBarButtonItem = rootSplitViewController.displayModeButtonItem
				detail.navigationItem.leftItemsSupplementBackButton = true
				masterNavigationController.pushViewController(detail, animated: false)
			}

		}
		
		return true
		
	}
	
	func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
		
		if isThreePanelMode {
			return transitionToThreePanelMode()
		}

		if let detail = masterNavigationController.viewControllers.last as? DetailViewController {

			// If we have a detail controller on the stack, remove it and return it.
			masterNavigationController.viewControllers.removeLast()
			let detailNav = addNavControllerIfNecessary(detail, showButton: true)
			return detailNav
			
		} else {

			// Display a no selection controller since we don't have any detail selected
			return fullyWrappedSystemMesssageController(showButton: true)

		}
	}
	
}

// MARK: UINavigationControllerDelegate

extension SceneCoordinator: UINavigationControllerDelegate {

	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		
		// If we are showing the Feeds and only the feeds start clearing stuff
		if viewController === masterFeedViewController && !isThreePanelMode {
			activityManager.invalidateCurrentActivities()
			selectFeed(nil)
		}
		
		// If we are using a phone and navigate away from the detail, clear up the article resources (including activity)
		if viewController === masterTimelineViewController && !isThreePanelMode && rootSplitViewController.isCollapsed {
			selectArticle(nil)
		}
		
	}
	
}

// MARK: Private

private extension SceneCoordinator {

	func updateUnreadCount() {
		var count = 0
		for article in articles {
			if !article.status.read {
				count += 1
			}
		}
		unreadCount = count
	}

	func rebuildBackingStores(_ updateExpandedNodes: (() -> Void)? = nil) {
		if !animatingChanges && !BatchUpdate.shared.isPerforming {
			treeController.rebuild()
			updateExpandedNodes?()
			rebuildShadowTable()
			masterFeedViewController.reloadFeeds()
		}
	}
	
	func rebuildShadowTable() {
		shadowTable = [[Node]]()

		for i in 0..<treeController.rootNode.numberOfChildNodes {
			
			var result = [Node]()
			let sectionNode = treeController.rootNode.childAtIndex(i)!
			
			if sectionNode.isExpanded {
				for node in sectionNode.childNodes {
					result.append(node)
					if node.isExpanded {
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
	
	func updateShowAvatars() {
		
		if showFeedNames {
			self.showAvatars = true
			return
		}
		
		for article in articles {
			if let authors = article.authors {
				for author in authors {
					if author.avatarURL != nil {
						self.showAvatars = true
						return
					}
				}
			}
		}
		
		self.showAvatars = false
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
				
				if node.isExpanded {
					continue
				}
				
				if unreadCountProvider.unreadCount > 0 {
					selectFeed(prevIndexPath)
					return true
				}
				
			}
			
		}
		
		return false
		
	}
	
	// MARK: Select Next Unread
	
	@discardableResult
	func selectFirstUnreadArticleInTimeline() -> Bool {
		return selectNextArticleInTimeline(startingRow: 0)
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
		
		return selectNextArticleInTimeline(startingRow: startingRow)
	}
	
	func selectNextArticleInTimeline(startingRow: Int) -> Bool {
		
		guard startingRow < articles.count else {
			return false
		}
		
		for i in startingRow..<articles.count {
			let article = articles[i]
			if !article.status.read {
				selectArticle(article)
				return true
			}
		}
		
		return false
		
	}
	
	func selectNextUnreadFeedFetcher() {
		
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
		
		if selectNextUnreadFeedFetcher(startingWith: nextIndexPath) {
			return
		}
		selectNextUnreadFeedFetcher(startingWith: IndexPath(row: 0, section: 0))
		
	}
	
	@discardableResult
	func selectNextUnreadFeedFetcher(startingWith indexPath: IndexPath) -> Bool {
		
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
					return true
				}
				
				if node.isExpanded {
					continue
				}
				
				if unreadCountProvider.unreadCount > 0 {
					selectFeed(nextIndexPath)
					return true
				}
				
			}
			
		}
		
		return false
		
	}
	
	// MARK: Fetching Articles
	
	func emptyTheTimeline() {
		if !articles.isEmpty {
			replaceArticles(with: Set<Article>(), animate: true)
		}
	}
	
	func sortParametersDidChange() {
		replaceArticles(with: Set(articles), animate: true)
	}
		
	func replaceArticles(with unsortedArticles: Set<Article>, animate: Bool) {
		let sortedArticles = Array(unsortedArticles).sortedByDate(sortDirection, groupByFeed: groupByFeed)
		
		if articles != sortedArticles {
			
			articles = sortedArticles
			updateShowAvatars()
			updateUnreadCount()
			
			masterTimelineViewController?.reloadArticles(animate: animate)
		}
	}
	
	func queueFetchAndMergeArticles() {
		fetchAndMergeArticlesQueue.add(self, #selector(fetchAndMergeArticles))
	}
	
	@objc func fetchAndMergeArticles() {
		
		guard let timelineFetcher = timelineFetcher else {
			return
		}
		
		fetchUnsortedArticlesAsync(for: [timelineFetcher]) { [weak self] (unsortedArticles) in
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

			strongSelf.replaceArticles(with: updatedArticles, animate: true)
		}
		
	}
	
	func cancelPendingAsyncFetches() {
		fetchSerialNumber += 1
		fetchRequestQueue.cancelAllRequests()
	}

	func fetchAndReplaceArticlesSync() {
		// To be called when the user has made a change of selection in the sidebar.
		// It blocks the main thread, so that there’s no async delay,
		// so that the entire display refreshes at once.
		// It’s a better user experience this way.
		cancelPendingAsyncFetches()
		guard let timelineFetcher = timelineFetcher else {
			emptyTheTimeline()
			return
		}
		let fetchedArticles = fetchUnsortedArticlesSync(for: [timelineFetcher])
		replaceArticles(with: fetchedArticles, animate: false)
	}

	func fetchAndReplaceArticlesAsync(completion: @escaping () -> Void) {
		// To be called when we need to do an entire fetch, but an async delay is okay.
		// Example: we have the Today feed selected, and the calendar day just changed.
		cancelPendingAsyncFetches()
		guard let timelineFetcher = timelineFetcher else {
			emptyTheTimeline()
			return
		}
		fetchUnsortedArticlesAsync(for: [timelineFetcher]) { [weak self] (articles) in
			self?.replaceArticles(with: articles, animate: true)
			completion()
		}
	}

	func fetchUnsortedArticlesSync(for representedObjects: [Any]) -> Set<Article> {
		cancelPendingAsyncFetches()
		let articleFetchers = representedObjects.compactMap{ $0 as? ArticleFetcher }
		if articleFetchers.isEmpty {
			return Set<Article>()
		}

		var fetchedArticles = Set<Article>()
		for articleFetcher in articleFetchers {
			fetchedArticles.formUnion(articleFetcher.fetchArticles())
		}
		return fetchedArticles
	}

	func fetchUnsortedArticlesAsync(for representedObjects: [Any], callback: @escaping ArticleSetBlock) {
		// The callback will *not* be called if the fetch is no longer relevant — that is,
		// if it’s been superseded by a newer fetch, or the timeline was emptied, etc., it won’t get called.
		precondition(Thread.isMainThread)
		cancelPendingAsyncFetches()
		let fetchOperation = FetchRequestOperation(id: fetchSerialNumber, representedObjects: representedObjects) { [weak self] (articles, operation) in
			precondition(Thread.isMainThread)
			guard !operation.isCanceled, let strongSelf = self, operation.id == strongSelf.fetchSerialNumber else {
				return
			}
			callback(articles)
		}
		fetchRequestQueue.add(fetchOperation)
	}

	func timelineFetcherContainsAnyPseudoFeed() -> Bool {
		if timelineFetcher is PseudoFeed {
			return true
		}
		return false
	}
	
	func timelineFetcherContainsAnyFolder() -> Bool {
		if timelineFetcher is Folder {
			return true
		}
		return false
	}
	
	func timelineFetcherContainsAnyFeed(_ feeds: Set<Feed>) -> Bool {
		
		// Return true if there’s a match or if a folder contains (recursively) one of feeds
		
		if let feed = timelineFetcher as? Feed {
			for oneFeed in feeds {
				if feed.feedID == oneFeed.feedID || feed.url == oneFeed.url {
					return true
				}
			}
		} else if let folder = timelineFetcher as? Folder {
			for oneFeed in feeds {
				if folder.hasFeed(with: oneFeed.feedID) || folder.hasFeed(withURL: oneFeed.url) {
					return true
				}
			}
		}
		
		return false
		
	}
	
	// MARK: Double Split
	
	func installTimelineControllerIfNecessary(animated: Bool) {
		if navControllerForTimeline().viewControllers.filter({ $0 is MasterTimelineViewController }).count < 1 {
			masterTimelineViewController = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
			masterTimelineViewController!.coordinator = self
			navControllerForTimeline().pushViewController(masterTimelineViewController!, animated: animated)
		}
	}
	
	func installDetailController(_ detailController: UIViewController, automated: Bool) {

		if let subSplit = subSplitViewController {
			let controller = addNavControllerIfNecessary(detailController, showButton: false)
			subSplit.showDetailViewController(controller, sender: self)
		} else if rootSplitViewController.isCollapsed {
			let controller = addNavControllerIfNecessary(detailController, showButton: false)
			masterNavigationController.pushViewController(controller, animated: !automated)
		} else {
			let controller = addNavControllerIfNecessary(detailController, showButton: true)
			rootSplitViewController.showDetailViewController(controller, sender: self)
  	 	}
		
	}
	
	func addNavControllerIfNecessary(_ controller: UIViewController, showButton: Bool) -> UIViewController {
		
		if rootSplitViewController.isCollapsed {
			
			return controller
			
		} else {
			
			let navController = ThemedNavigationController.template(rootViewController: controller)
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

	func configureDoubleSplit() {
		rootSplitViewController.preferredPrimaryColumnWidthFraction = 0.30
		
		let subSplit = UISplitViewController.template()
		subSplit.preferredDisplayMode = .allVisible
		subSplit.preferredPrimaryColumnWidthFraction = 0.4285
		
		rootSplitViewController.showDetailViewController(subSplit, sender: self)
	}
	
	func navControllerForTimeline() -> UINavigationController {
		if let subSplit = subSplitViewController {
			return subSplit.viewControllers.first as! UINavigationController
		} else {
			return masterNavigationController
		}
	}
	
	func fullyWrappedSystemMesssageController(showButton: Bool) -> UIViewController {
		let systemMessageViewController = UIStoryboard.main.instantiateController(ofType: SystemMessageViewController.self)
		let navController = addNavControllerIfNecessary(systemMessageViewController, showButton: showButton)
		return navController
	}
	
	@discardableResult
	func transitionToThreePanelMode() -> UIViewController {
		
		defer {
			masterNavigationController.viewControllers = [masterFeedViewController]
		}
		
		let controller: UIViewController = {
			if let result = detailViewController {
				return result
			} else {
				return UIStoryboard.main.instantiateController(ofType: SystemMessageViewController.self)
			}
		}()
		
		configureDoubleSplit()
		installTimelineControllerIfNecessary(animated: false)
		masterTimelineViewController?.navigationItem.leftBarButtonItem = rootSplitViewController.displayModeButtonItem
		masterTimelineViewController?.navigationItem.leftItemsSupplementBackButton = true

		// Create the new sub split controller and add the timeline in the primary position
		let masterTimelineNavController = subSplitViewController!.viewControllers.first as! UINavigationController
		masterTimelineNavController.viewControllers = [masterTimelineViewController!]

		// Put the detail or no selection controller in the secondary (or detail) position of the sub split
		let navController = addNavControllerIfNecessary(controller, showButton: false)
		subSplitViewController!.showDetailViewController(navController, sender: self)
		
		masterFeedViewController.restoreSelectionIfNecessary(adjustScroll: true)
		masterTimelineViewController!.restoreSelectionIfNecessary()
		
		// We made sure this was there above when we called configureDoubleSplit
		return subSplitViewController!

	}
	
	func transitionFromThreePanelMode() {

		rootSplitViewController.preferredPrimaryColumnWidthFraction = UISplitViewController.automaticDimension
		
		if let subSplit = rootSplitViewController.viewControllers.last as? UISplitViewController {

			// Push a new timeline on to the master navigation controller.  For some reason recycling the timeline can freak
			// the system out and throw it into an infinite loop.
			if currentFeedIndexPath != nil {
				masterTimelineViewController = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
				masterTimelineViewController!.coordinator = self
				masterNavigationController.pushViewController(masterTimelineViewController!, animated: false)
			}

			// Pull the detail or no selection controller out of the sub split second position and move it to the root split controller
			// secondary (detail) position.
			if let detailNav = subSplit.viewControllers.last as? UINavigationController, let topController = detailNav.topViewController {
				let newNav = addNavControllerIfNecessary(topController, showButton: true)
				rootSplitViewController.showDetailViewController(newNav, sender: self)
			}

		}
		
	}
	
	// MARK: NSUserActivity
	
	func updateSelectingActivity(with node: Node) {
		switch true {
		case node.representedObject === SmartFeedsController.shared.todayFeed:
			activityManager.selectingToday()
		case node.representedObject === SmartFeedsController.shared.unreadFeed:
			activityManager.selectingAllUnread()
		case node.representedObject === SmartFeedsController.shared.starredFeed:
			activityManager.selectingStarred()
		case node.representedObject is Folder:
			activityManager.selectingFolder(node.representedObject as! Folder)
		case node.representedObject is Feed:
			activityManager.selectingFeed(node.representedObject as! Feed)
		default:
			break
		}
	}
	
	func handleSelectToday() {
		if let indexPath = indexPathFor(SmartFeedsController.shared.todayFeed) {
			selectFeed(indexPath)
		}
	}
	
	func handleSelectAllUnread() {
		if let indexPath = indexPathFor(SmartFeedsController.shared.unreadFeed) {
			selectFeed(indexPath)
		}
	}
	
	func handleSelectStarred() {
		if let indexPath = indexPathFor(SmartFeedsController.shared.starredFeed) {
			selectFeed(indexPath)
		}
	}
	
	func handleSelectFolder(_ activity: NSUserActivity) {
		guard let accountNode = findAccountNode(for: activity), let folderNode = findFolderNode(for: activity, beginningAt: accountNode) else {
			return
		}
		if let indexPath = indexPathFor(folderNode) {
			selectFeed(indexPath)
		}
	}
	
	func handleSelectFeed(_ activity: NSUserActivity) {
		guard let accountNode = findAccountNode(for: activity), let feedNode = findFeedNode(for: activity, beginningAt: accountNode) else {
			return
		}
		if let feed = feedNode.representedObject as? Feed {
			discloseFeed(feed)
		}
	}
	
	func handleReadArticle(_ activity: NSUserActivity) {
		guard let accountNode = findAccountNode(for: activity), let feedNode = findFeedNode(for: activity, beginningAt: accountNode) else {
			return
		}
		
		discloseFeed(feedNode.representedObject as! Feed) {
		
			guard let articleID = activity.userInfo?[ActivityID.articleID.rawValue] as? String else { return }
			if let article = self.articles.first(where: { $0.articleID == articleID }) {
				self.selectArticle(article)
			}
			
		}
	}
	
	func findAccountNode(for activity: NSUserActivity) -> Node? {
		guard let accountID = activity.userInfo?[ActivityID.accountID.rawValue] as? String else {
			return nil
		}
		
		if let node = treeController.rootNode.descendantNode(where: { ($0.representedObject as? Account)?.accountID == accountID }) {
			return node
		}

		guard let accountName = activity.userInfo?[ActivityID.accountName.rawValue] as? String else {
			return nil
		}

		if let node = treeController.rootNode.descendantNode(where: { ($0.representedObject as? Account)?.name == accountName }) {
			return node
		}

		return nil
	}
	
	func findFolderNode(for activity: NSUserActivity, beginningAt startingNode: Node) -> Node? {
		guard let folderName = activity.userInfo?[ActivityID.folderName.rawValue] as? String else {
			return nil
		}
		if let node = startingNode.descendantNode(where: { ($0.representedObject as? Folder)?.nameForDisplay == folderName }) {
			return node
		}
		return nil
	}

	func findFeedNode(for activity: NSUserActivity, beginningAt startingNode: Node) -> Node? {
		guard let feedID = activity.userInfo?[ActivityID.feedID.rawValue] as? String else {
			return nil
		}
		if let node = startingNode.descendantNode(where: { ($0.representedObject as? Feed)?.feedID == feedID }) {
			return node
		}
		return nil
	}
	
}

// MARK: SwiftUI

struct SceneCoordinatorHolder {
	weak var value: SceneCoordinator?
}

struct SceneCoordinatorKey: EnvironmentKey {
	static var defaultValue: SceneCoordinatorHolder { return SceneCoordinatorHolder(value: nil ) }
}

extension EnvironmentValues {
	var sceneCoordinator: SceneCoordinator? {
		get { return self[SceneCoordinatorKey.self].value }
		set { self[SceneCoordinatorKey.self].value = newValue }
	}
}
