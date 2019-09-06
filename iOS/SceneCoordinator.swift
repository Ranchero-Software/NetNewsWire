//
//  NavigationModelController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
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
	
	private var detailViewController: DetailViewController? {
		if let detail = masterNavigationController.viewControllers.last as? DetailViewController {
			return detail
		}
		if let subSplit = rootSplitViewController.viewControllers.last?.children.first as? UISplitViewController {
			if let navController = subSplit.viewControllers.last as? UINavigationController {
				return navController.topViewController as? DetailViewController
			}
		} else {
			if let navController = rootSplitViewController.viewControllers.last?.children.first as? UINavigationController {
				return navController.topViewController as? DetailViewController
			}
		}
		return nil
	}
	
	private let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5)
	private var fetchSerialNumber = 0
	private let fetchRequestQueue = FetchRequestQueue()
	private var articleRowMap = [String: Int]() // articleID: rowIndex
	
	private var animatingChanges = false
	private var expandedNodes = [Node]()
	private var shadowTable = [[Node]]()
	private var lastSearchString = ""
	private var lastSearchScope: SearchScope? = nil
	private var isSearching: Bool = false
	private var searchArticleIds: Set<String>? = nil
	
	private(set) var sortDirection = AppDefaults.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortDirectionDidChange()
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
		return rootSplitViewController.traitCollection.userInterfaceIdiom == .pad &&
			!rootSplitViewController.isCollapsed &&
			rootSplitViewController.displayMode == .allVisible
	}
	
	var rootNode: Node {
		return treeController.rootNode
	}
	
	var allSections: [Int] {
		var sections = [Int]()
		for (index, _) in shadowTable.enumerated() {
			sections.append(index)
		}
		return sections
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
		guard let indexPath = currentArticleIndexPath else {
			return false
		}
		return indexPath.row > 0
	}
	
	var isNextArticleAvailable: Bool {
		guard let indexPath = currentArticleIndexPath else {
			return false
		}
		return indexPath.row + 1 < articles.count
	}
	
	var prevArticleIndexPath: IndexPath? {
		guard isPrevArticleAvailable, let indexPath = currentArticleIndexPath else {
			return nil
		}
		return IndexPath(row: indexPath.row - 1, section: indexPath.section)
	}
	
	var nextArticleIndexPath: IndexPath? {
		guard isNextArticleAvailable, let indexPath = currentArticleIndexPath else {
			return nil
		}
		return IndexPath(row: indexPath.row + 1, section: indexPath.section)
	}
	
	var firstUnreadArticleIndexPath: IndexPath? {
		for (row, article) in articles.enumerated() {
			if !article.status.read {
				return IndexPath(row: row, section: 0)
			}
		}
		return nil
	}
	
	var currentArticle: Article? {
		if let indexPath = currentArticleIndexPath, indexPath.row < articles.count {
			return articles[indexPath.row]
		}
		return nil
	}
	
	private(set) var currentArticleIndexPath: IndexPath?
	
	private(set) var articles = ArticleArray()
	
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
			expandedNodes.append(section)
			shadowTable.append([Node]())
		}
		
		rebuildShadowTable()
		
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .AccountsDidChange, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
		
		// Force lazy initialization of the web view provider so that it can warm up the queue of prepared web views
		let _ = DetailViewControllerWebViewProvider.shared
	}
	
	func start() -> UIViewController {
		rootSplitViewController = RootSplitViewController()
		rootSplitViewController.coordinator = self
		rootSplitViewController.preferredDisplayMode = .automatic
		rootSplitViewController.viewControllers = [ThemedNavigationController.template()]
		rootSplitViewController.delegate = self
		
		masterNavigationController = (rootSplitViewController.viewControllers.first as! UINavigationController)
		masterNavigationController.delegate = self
		
		masterFeedViewController = UIStoryboard.main.instantiateController(ofType: MasterFeedViewController.self)
		masterFeedViewController.coordinator = self
		masterNavigationController.pushViewController(masterFeedViewController, animated: false)
		
		let systemMessageViewController = UIStoryboard.main.instantiateController(ofType: SystemMessageViewController.self)
		let detailNavController = addNavControllerIfNecessary(systemMessageViewController, showButton: true)
		let shimController = UIViewController()
		shimController.replaceChildAndPinView(detailNavController)
		rootSplitViewController.showDetailViewController(shimController, sender: self)

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
	
	func selectFirstUnreadInAllUnread() {
		selectFeed(IndexPath(row: 1, section: 0))
		selectFirstUnreadArticleInTimeline()
	}

	func showSearch() {
		selectFeed(nil)
		masterTimelineViewController?.showSearchAll()
	}
	
	// MARK: Notifications
	
	@objc func statusesDidChange(_ note: Notification) {
		updateUnreadCount()
	}
	
	@objc func containerChildrenDidChange(_ note: Notification) {
		rebuildBackingStores()
		if timelineFetcherContainsAnyPseudoFeed() || timelineFetcherContainsAnyFolder() {
			fetchAndReplaceArticlesAsync() {}
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
			fetchAndReplaceArticlesSync()
		}
		rebuildBackingStores()
	}
	
	@objc func accountsDidChange(_ note: Notification) {
		if timelineFetcherContainsAnyPseudoFeed() {
			fetchAndReplaceArticlesSync()
		}
		rebuildBackingStores()
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		self.sortDirection = AppDefaults.timelineSortDirection
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
	
	func rowsInSection(_ section: Int) -> Int {
		return shadowTable[section].count
	}
	
	func isExpanded(_ node: Node) -> Bool {
		return expandedNodes.contains(node)
	}
	
	func nodeFor(_ indexPath: IndexPath) -> Node? {
		guard indexPath.section < shadowTable.count && indexPath.row < shadowTable[indexPath.section].count else {
			return nil
		}
		return shadowTable[indexPath.section][indexPath.row]
	}
	
	func nodesFor(section: Int) -> [Node] {
		return shadowTable[section]
	}
	
	func cappedIndexPath(_ indexPath: IndexPath) -> IndexPath {
		guard indexPath.section < shadowTable.count && indexPath.row < shadowTable[indexPath.section].count else {
			return IndexPath(row: shadowTable[shadowTable.count - 1].count - 1, section: shadowTable.count - 1)
		}
		return indexPath
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
		
	func expandSection(_ section: Int) {
		guard let expandNode = treeController.rootNode.childAtIndex(section), !expandedNodes.contains(expandNode) else {
			return
		}

		expandedNodes.append(expandNode)
		
		animatingChanges = true
		
		var i = 0
		
		func addNode(_ node: Node) {
			shadowTable[section].insert(node, at: i)
			i = i + 1
		}
		
		for child in expandNode.childNodes {
			addNode(child)
			if expandedNodes.contains(child) {
				for gChild in child.childNodes {
					addNode(gChild)
				}
			}
		}
		
		animatingChanges = false
	}
	
	func expandAllSectionsAndFolders() {
		for (sectionIndex, sectionNode) in treeController.rootNode.childNodes.enumerated() {

			expandSection(sectionIndex)
			
			for topLevelNode in sectionNode.childNodes {
				if topLevelNode.representedObject is Folder, let indexPath = indexPathFor(topLevelNode) {
					expandFolder(indexPath)
				}
			}

		}
	}
	
	func expandFolder(_ indexPath: IndexPath) {
		let expandNode = shadowTable[indexPath.section][indexPath.row]
		guard !expandedNodes.contains(expandNode) else { return }
		expandedNodes.append(expandNode)
		
		animatingChanges = true
		
		for i in 0..<expandNode.childNodes.count {
			if let child = expandNode.childAtIndex(i) {
				let nextIndex = indexPath.row + i + 1
				shadowTable[indexPath.section].insert(child, at: nextIndex)
			}
		}
		
		animatingChanges = false
	}
	
	func collapseSection(_ section: Int) {
		guard let collapseNode = treeController.rootNode.childAtIndex(section), expandedNodes.contains(collapseNode) else {
			return
		}
		
		animatingChanges = true

		if let removeNode = expandedNodes.firstIndex(of: collapseNode) {
			expandedNodes.remove(at: removeNode)
		}
		
		shadowTable[section] = [Node]()
		
		animatingChanges = false
	}
	
	func collapseAllFolders() {
		for sectionNode in treeController.rootNode.childNodes {
			for topLevelNode in sectionNode.childNodes {
				if topLevelNode.representedObject is Folder, let indexPath = indexPathFor(topLevelNode) {
					collapseFolder(indexPath)
				}
			}
		}
	}
	
	func collapseFolder(_ indexPath: IndexPath) {
		animatingChanges = true
		
		let collapseNode = shadowTable[indexPath.section][indexPath.row]
		guard expandedNodes.contains(collapseNode) else { return }
		if let removeNode = expandedNodes.firstIndex(of: collapseNode) {
			expandedNodes.remove(at: removeNode)
		}
		
		for child in collapseNode.childNodes {
			if let index = shadowTable[indexPath.section].firstIndex(of: child) {
				shadowTable[indexPath.section].remove(at: index)
			}
		}
		
		animatingChanges = false
	}
	
	func masterFeedIndexPathForCurrentTimeline() -> IndexPath? {
		guard let node = treeController.rootNode.descendantNode(where: { return $0.representedObject === timelineFetcher as AnyObject }) else {
			return nil
		}
		return indexPathFor(node)
	}
	
	func indexForArticleID(_ articleID: String?) -> Int? {
		guard let articleID = articleID else { return nil }
		updateArticleRowMapIfNeeded()
		return articleRowMap[articleID]
	}
	
	func indexesForArticleIDs(_ articleIDs: Set<String>) -> IndexSet {
		var indexes = IndexSet()
		
		articleIDs.forEach { (articleID) in
			guard let oneIndex = indexForArticleID(articleID) else {
				return
			}
			if oneIndex != NSNotFound {
				indexes.insert(oneIndex)
			}
		}
		
		return indexes
	}

	func selectFeed(_ indexPath: IndexPath?, automated: Bool = true) {
		selectArticle(nil)
		currentFeedIndexPath = indexPath

		if let ip = indexPath, let node = nodeFor(ip), let fetcher = node.representedObject as? ArticleFetcher {
			timelineFetcher = fetcher
			updateSelectingActivity(with: node)

			if navControllerForTimeline().viewControllers.filter({ $0 is MasterTimelineViewController }).count < 1 {
				masterTimelineViewController = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
				masterTimelineViewController!.coordinator = self
				navControllerForTimeline().pushViewController(masterTimelineViewController!, animated: !automated)
			}
		} else {
			timelineFetcher = nil

			if rootSplitViewController.isCollapsed && navControllerForTimeline().viewControllers.last is MasterTimelineViewController {
				navControllerForTimeline().popViewController(animated: !automated)
			}
		}
		
		masterFeedViewController.updateFeedSelection()
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

	func selectArticle(_ indexPath: IndexPath?, automated: Bool = true) {
		currentArticleIndexPath = indexPath
		activityManager.reading(currentArticle)
		
		if let article = currentArticle {
			markArticles(Set([article]), statusKey: .read, flag: true)
		}

		if indexPath == nil {
			if rootSplitViewController.isCollapsed {
				if masterNavigationController.children.last is DetailViewController {
					masterNavigationController.popViewController(animated: false)
				}
			} else {
				let systemMessageViewController = UIStoryboard.main.instantiateController(ofType: SystemMessageViewController.self)
				installDetailController(systemMessageViewController, automated: automated)
			}
			masterTimelineViewController?.updateArticleSelection(animate: true)
			return
		}
		
		if detailViewController == nil {
			let detailViewController = UIStoryboard.main.instantiateController(ofType: DetailViewController.self)
			detailViewController.coordinator = self
			installDetailController(detailViewController, automated: automated)
		}
		
		// Automatically hide the overlay
		if rootSplitViewController.displayMode == .primaryOverlay {
			UIView.animate(withDuration: 0.3) {
				self.rootSplitViewController.preferredDisplayMode = .primaryHidden
			}
			rootSplitViewController.preferredDisplayMode = .automatic
		}

		if automated {
			masterTimelineViewController?.updateArticleSelection(animate: false)
		}
		
		detailViewController?.updateArticleSelection()
		
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
		if let indexPath = prevArticleIndexPath {
			selectArticle(indexPath)
		}
	}
	
	func selectNextArticle() {
		if let indexPath = nextArticleIndexPath {
			selectArticle(indexPath)
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
		if let indexPath = currentArticleIndexPath {
			markAsReadOlderArticlesInTimeline(indexPath)
		}
	}
	func markAsReadOlderArticlesInTimeline(_ indexPath: IndexPath) {
		let article = articles[indexPath.row]
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
	
	func toggleRead(for indexPath: IndexPath) {
		let article = articles[indexPath.row]
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
	
	func toggleStar(for indexPath: IndexPath) {
		let article = articles[indexPath.row]
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
		let settingsNavViewController = UIStoryboard.settings.instantiateInitialViewController() as! UINavigationController
		settingsNavViewController.modalPresentationStyle = .formSheet
		let settingsViewController = settingsNavViewController.topViewController as! SettingsViewController
		settingsViewController.presentingParentController = rootSplitViewController
		rootSplitViewController.present(settingsNavViewController, animated: true)
		
		//		let settings = UIHostingController(rootView: SettingsView(viewModel: SettingsView.ViewModel()))
		//		self.present(settings, animated: true)
	}
	
	func showAdd(_ type: AddControllerType) {
		let addViewController = UIStoryboard.add.instantiateInitialViewController() as! UINavigationController
		let containerController = addViewController.topViewController as! AddContainerViewController
		containerController.initialControllerType = type
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
	
	func showBrowserForArticle(_ indexPath: IndexPath) {
		guard let preferredLink = articles[indexPath.row].preferredLink, let url = URL(string: preferredLink) else {
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
		if currentArticleIndexPath == nil {
			selectArticle(IndexPath(row: 0, section: 0))
		}
		masterTimelineViewController?.focus()
	}
	
	func navigateToDetail() {
		detailViewController?.focus()
	}
	
}

// MARK: UISplitViewControllerDelegate

extension SceneCoordinator: UISplitViewControllerDelegate {

	func splitViewController(_ splitViewController: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode) {
		guard splitViewController.traitCollection.userInterfaceIdiom == .pad && !splitViewController.isCollapsed else {
			return
		}
		if splitViewController.displayMode != .allVisible && displayMode == .allVisible {
			transitionToThreePanelMode()
		}
		if splitViewController.displayMode == .allVisible && displayMode != .allVisible {
			transitionFromThreePanelMode()
		}
	}
	
	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
	
		// Check to see if the system is currently configured for three panel mode
		if let subSplit = secondaryViewController.children.first as? UISplitViewController {

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
			if let detailNav = secondaryViewController.children.first as? UINavigationController, let detail = detailNav.topViewController as? DetailViewController {
				// I have no idea why, I have to wire up the left bar button item for this, but not when I am transitioning from three panel mode
				detail.navigationItem.leftBarButtonItem = rootSplitViewController.displayModeButtonItem
				detail.navigationItem.leftItemsSupplementBackButton = true
				masterNavigationController.pushViewController(detail, animated: false)
			}

		}
		
		return true
		
	}
	
	func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
		
		// If we are in three panel mode, return back the new shim controller that contains a new sub split controller
		if isThreePanelMode {
			return transitionToThreePanelMode()
		}

		if let detail = masterNavigationController.viewControllers.last as? DetailViewController {

			// If we have a detail controller on the stack, remove it, wrap it in a shim, and return it.
			masterNavigationController.viewControllers.removeLast()
			let detailNav = addNavControllerIfNecessary(detail, showButton: true)
			let shimController = UIViewController()
			shimController.addChildAndPinView(detailNav)
			return shimController
			
		} else {

			// Display a no selection controller since we don't have any detail selected
			return fullyWrappedSystemMesssageController(showButton: true)

		}
	}
	
}

// MARK: UINavigationControllerDelegate

extension SceneCoordinator: UINavigationControllerDelegate {
	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		if rootSplitViewController.isCollapsed && viewController === masterFeedViewController {
			activityManager.invalidateCurrentActivities()
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

	func rebuildBackingStores() {
		if !animatingChanges && !BatchUpdate.shared.isPerforming {
			treeController.rebuild()
			rebuildShadowTable()
			masterFeedViewController.reloadFeeds()
		}
	}
	
	func rebuildShadowTable() {
		shadowTable = [[Node]]()

		for i in 0..<treeController.rootNode.numberOfChildNodes {
			
			var result = [Node]()
			if let nodes = treeController.rootNode.childAtIndex(i)?.childNodes {
				for node in nodes {
					result.append(node)
					if expandedNodes.contains(node) {
						for child in node.childNodes {
							result.append(child)
						}
					}
				}
			}
			
			shadowTable.append(result)
			
		}
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
			if let indexPath = currentArticleIndexPath {
				return indexPath.row - 1
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
				selectArticle(IndexPath(row: i, section: 0))
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
				
				if expandedNodes.contains(node) {
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
			if let indexPath = currentArticleIndexPath {
				return indexPath.row + 1
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
				selectArticle(IndexPath(row: i, section: 0))
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
				
				if expandedNodes.contains(node) {
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
	
	func sortDirectionDidChange() {
		replaceArticles(with: Set(articles), animate: true)
	}
	
	func replaceArticles(with unsortedArticles: Set<Article>, animate: Bool) {
		let sortedArticles = Array(unsortedArticles).sortedByDate(sortDirection)
		
		if articles != sortedArticles {
			
			let article = currentArticle
			articles = sortedArticles
			
			updateShowAvatars()
			articleRowMap = [String: Int]()
			updateUnreadCount()
			
			masterTimelineViewController?.reloadArticles(animate: animate)
			if let articleID = article?.articleID, let index = indexForArticleID(articleID) {
				currentArticleIndexPath = IndexPath(row: index, section: 0)
			}
			
		}
	}
	
	func updateArticleRowMap() {
		var rowMap = [String: Int]()
		var index = 0
		articles.forEach { (article) in
			rowMap[article.articleID] = index
			index += 1
		}
		articleRowMap = rowMap
	}
	
	func updateArticleRowMapIfNeeded() {
		if articleRowMap.isEmpty {
			updateArticleRowMap()
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
	
	// Note about the Shim Controller
	// In the root split view controller's secondary (or detail) position we use a view controller that
	// only acts as a shim (or wrapper) for the actually desired contents of the second position.  This
	// is because we normally can't change the root split view controllers second position contents
	// during the display mode change callback (in the split view controller delegate).  To fool the
	// system, we leave the same controller, the shim, in place and change its child controllers instead.
	
	func installDetailController(_ detailController: UIViewController, automated: Bool) {
		let showButton = rootSplitViewController.displayMode != .allVisible
		let controller = addNavControllerIfNecessary(detailController, showButton: showButton)
		
		if isThreePanelMode {
			let targetSplit = ensureDoubleSplit().children.first as! UISplitViewController
			targetSplit.showDetailViewController(controller, sender: self)
		} else if rootSplitViewController.isCollapsed {
			masterNavigationController.pushViewController(controller, animated: !automated)
		} else {
			if let shimController = rootSplitViewController.viewControllers.last {
				shimController.replaceChildAndPinView(controller)
			}
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
			}
			return navController
		}
	}

	func ensureDoubleSplit() -> UIViewController {
		if let shimController = rootSplitViewController.viewControllers.last, shimController.children.first is UISplitViewController {
			return shimController
		}
		
		rootSplitViewController.preferredPrimaryColumnWidthFraction = 0.30
		
		let subSplit = UISplitViewController.template()
		subSplit.preferredDisplayMode = .allVisible
		subSplit.preferredPrimaryColumnWidthFraction = 0.4285
		
		let shimController = UIViewController()
		shimController.addChildAndPinView(subSplit)
		
		rootSplitViewController.showDetailViewController(shimController, sender: self)
		return shimController
	}
	
	func navControllerForTimeline() -> UINavigationController {
		if isThreePanelMode {
			let subSplit = ensureDoubleSplit().children.first as! UISplitViewController
			return subSplit.viewControllers.first as! UINavigationController
		} else {
			return masterNavigationController
		}
	}
	
	func fullyWrappedSystemMesssageController(showButton: Bool) -> UIViewController {
		let systemMessageViewController = UIStoryboard.main.instantiateController(ofType: SystemMessageViewController.self)
		let navController = addNavControllerIfNecessary(systemMessageViewController, showButton: showButton)
		let shimController = UIViewController()
		shimController.addChildAndPinView(navController)
		return shimController
	}
	
	@discardableResult
	func transitionToThreePanelMode() -> UIViewController {
		defer {
			masterNavigationController.viewControllers = [masterFeedViewController]
		}

		if currentFeedIndexPath == nil && currentArticleIndexPath == nil {
			
			let wrappedSystemMessageController = fullyWrappedSystemMesssageController(showButton: false)
			rootSplitViewController.showDetailViewController(wrappedSystemMessageController, sender: self)
			return wrappedSystemMessageController
			
		} else {
			
			let controller: UIViewController = {
				if let result = detailViewController {
					return result
				} else {
					return UIStoryboard.main.instantiateController(ofType: SystemMessageViewController.self)
				}
			}()
			
			// Create the new sub split controller (wrapped in the shim of course) and add the timeline in the primary position
			let shimController = ensureDoubleSplit()
			let subSplit = shimController.children.first as! UISplitViewController
			let masterTimelineNavController = subSplit.viewControllers.first as! UINavigationController
			masterTimelineNavController.viewControllers = [masterTimelineViewController!]
			
			// Put the detail or no selection controller in the secondary (or detail) position of the sub split
			let navController = addNavControllerIfNecessary(controller, showButton: false)
			subSplit.showDetailViewController(navController, sender: self)
			
			return shimController
		}
	}
	
	func transitionFromThreePanelMode() {
		
		rootSplitViewController.preferredPrimaryColumnWidthFraction = UISplitViewController.automaticDimension
		
		if let shimController = rootSplitViewController.viewControllers.last, let subSplit = shimController.children.first as? UISplitViewController {

			// Push the timeline on to the master navigation controller.  This should always be true if we have installed
			// the sub split controller because we only install the sub split controller if a timeline needs to be displayed.
			if let masterTimelineNav = subSplit.viewControllers.first as? UINavigationController, let masterTimeline = masterTimelineNav.topViewController {
				masterNavigationController.pushViewController(masterTimeline, animated: false)
			}

			// Pull the detail or no selection controller out of the sub split second position and move it to the root split controller
			// secondary (detail) position, by replacing the contents of the shim controller in the second position.
			if let detailNav = subSplit.viewControllers.last as? UINavigationController, let topController = detailNav.topViewController {
				let newNav = addNavControllerIfNecessary(topController, showButton: true)
				shimController.replaceChildAndPinView(newNav)
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
		
			for (index, article) in self.articles.enumerated() {
				if article.articleID == articleID {
					self.selectArticle(IndexPath(row: index, section: 0))
					break
				}
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
