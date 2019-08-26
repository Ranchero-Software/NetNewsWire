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

class AppCoordinator: NSObject, UndoableCommandRunner, UnreadCountProvider {
	
	var undoableCommands = [UndoableCommand]()
	var undoManager: UndoManager? {
		return rootSplitViewController.undoManager
	}
	
	private var rootSplitViewController: UISplitViewController!
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
	
	private(set) var sortDirection = AppDefaults.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortDirectionDidChange()
			}
		}
	}

	private let treeControllerDelegate = FeedTreeControllerDelegate()
	private(set) lazy var treeController: TreeController = {
		return TreeController(delegate: treeControllerDelegate)
	}()
	
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
	
	var numberOfSections: Int {
		return shadowTable.count
	}

	private(set) var currentMasterIndexPath: IndexPath? {
		didSet {
			guard let ip = currentMasterIndexPath, let node = nodeFor(ip) else {
				assertionFailure()
				return
			}
			if let fetcher = node.representedObject as? ArticleFetcher {
				timelineFetcher = fetcher
			}
			masterFeedViewController.updateFeedSelection()
			updateSelectingActivity(with: node)
		}
	}
	
	var timelineName: String? {
		return (timelineFetcher as? DisplayNameProvider)?.nameForDisplay
	}
	
	var timelineFetcher: ArticleFetcher? {
		didSet {
			currentArticleIndexPath = nil
			if timelineFetcher is Feed {
				showFeedNames = false
			} else {
				showFeedNames = true
			}
			fetchAndReplaceArticlesSync()
			masterTimelineViewController?.reinitializeArticles()
		}
	}
	
	private(set) var showFeedNames = false
	private(set) var showAvatars = false

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
		guard let indexPath = currentArticleIndexPath else {
			return nil
		}
		return IndexPath(row: indexPath.row - 1, section: indexPath.section)
	}
	
	var nextArticleIndexPath: IndexPath? {
		guard let indexPath = currentArticleIndexPath else {
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
		if let indexPath = currentArticleIndexPath {
			return articles[indexPath.row]
		}
		return nil
	}
	
	private(set) var currentArticleIndexPath: IndexPath? {
		didSet {
			if currentArticleIndexPath != oldValue {
				masterTimelineViewController?.updateArticleSelection()
				detailViewController?.updateArticleSelection()
			}
		}
	}
	
	private(set) var articles = ArticleArray() {
		didSet {
			if articles == oldValue {
				return
			}
			if articles.representSameArticlesInSameOrder(as: oldValue) {
				articleRowMap = [String: Int]()
				masterTimelineViewController?.updateArticles()
				updateUnreadCount()
				return
			}
			updateShowAvatars()
			articleRowMap = [String: Int]()
			masterTimelineViewController?.reloadArticles()
			updateUnreadCount()
		}
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
	}
	
	func start() -> UIViewController {
		rootSplitViewController = UISplitViewController.template()
		rootSplitViewController.delegate = self
		
		masterNavigationController = (rootSplitViewController.viewControllers.first as! UINavigationController)
		
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
		guard let activityType = ActivityType(rawValue: activity.activityType) else { return }
		switch activityType {
		case .selectToday:
			handleSelectToday()
		case .selectAllUnread:
			handleSelectAllUnread()
		case .selectStarred:
			handleSelectStarred()
		case .readArticle:
			handleReadArticle(activity)
		}
	}
	
	// MARK: Notifications
	
	@objc func statusesDidChange(_ note: Notification) {
		updateUnreadCount()
	}
	
	@objc func containerChildrenDidChange(_ note: Notification) {
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
			fetchAndReplaceArticlesAsync()
		}
		rebuildBackingStores()
	}
	
	@objc func accountsDidChange(_ note: Notification) {
		if timelineFetcherContainsAnyPseudoFeed() {
			fetchAndReplaceArticlesAsync()
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
	
	func beginUpdates() {
		animatingChanges = true
	}

	func endUpdates() {
		animatingChanges = false
	}
	
	func rowsInSection(_ section: Int) -> Int {
		return shadowTable[section].count
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

	func isExpanded(_ node: Node) -> Bool {
		return expandedNodes.contains(node)
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
	
	func unreadCountFor(_ node: Node) -> Int {
		// The coordinator supplies the unread count for the currently selected feed node
		if let indexPath = currentMasterIndexPath, let selectedNode = nodeFor(indexPath), selectedNode == node {
			return unreadCount
		}
		if let unreadCountProvider = node.representedObject as? UnreadCountProvider {
			return unreadCountProvider.unreadCount
		}
		return 0
	}
		
	func expand(section: Int, completion: ([IndexPath]) -> ()) {
		
		guard let expandNode = treeController.rootNode.childAtIndex(section) else {
			return
		}
		expandedNodes.append(expandNode)
		
		animatingChanges = true
		
		var indexPathsToInsert = [IndexPath]()
		var i = 0
		
		func addNode(_ node: Node) {
			indexPathsToInsert.append(IndexPath(row: i, section: section))
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
		
		completion(indexPathsToInsert)
		
		animatingChanges = false
		
	}
	
	func expand(_ indexPath: IndexPath, completion: ([IndexPath]) -> ()) {
		
		let expandNode = shadowTable[indexPath.section][indexPath.row]
		expandedNodes.append(expandNode)
		
		animatingChanges = true
		
		var indexPathsToInsert = [IndexPath]()
		for i in 0..<expandNode.childNodes.count {
			if let child = expandNode.childAtIndex(i) {
				let nextIndex = indexPath.row + i + 1
				indexPathsToInsert.append(IndexPath(row: nextIndex, section: indexPath.section))
				shadowTable[indexPath.section].insert(child, at: nextIndex)
			}
		}
		
		completion(indexPathsToInsert)
		
		animatingChanges = false
		
	}
	
	func collapse(section: Int, completion: ([IndexPath]) -> ()) {
		
		animatingChanges = true
		
		guard let collapseNode = treeController.rootNode.childAtIndex(section) else {
			return
		}
		
		if let removeNode = expandedNodes.firstIndex(of: collapseNode) {
			expandedNodes.remove(at: removeNode)
		}
		
		var indexPathsToRemove = [IndexPath]()
		for i in 0..<shadowTable[section].count {
			indexPathsToRemove.append(IndexPath(row: i, section: section))
		}
		shadowTable[section] = [Node]()
		
		completion(indexPathsToRemove)
		
		animatingChanges = false
		
	}
	
	func collapse(_ indexPath: IndexPath, completion: ([IndexPath]) -> ()) {
		
		animatingChanges = true
		
		let collapseNode = shadowTable[indexPath.section][indexPath.row]
		if let removeNode = expandedNodes.firstIndex(of: collapseNode) {
			expandedNodes.remove(at: removeNode)
		}
		
		var indexPathsToRemove = [IndexPath]()
		
		for child in collapseNode.childNodes {
			if let index = shadowTable[indexPath.section].firstIndex(of: child) {
				indexPathsToRemove.append(IndexPath(row: index, section: indexPath.section))
			}
		}
		
		for child in collapseNode.childNodes {
			if let index = shadowTable[indexPath.section].firstIndex(of: child) {
				shadowTable[indexPath.section].remove(at: index)
			}
		}
		
		completion(indexPathsToRemove)
		
		animatingChanges = false
		
	}
	
	func indexesForArticleIDs(_ articleIDs: Set<String>) -> IndexSet {
		var indexes = IndexSet()
		
		articleIDs.forEach { (articleID) in
			guard let oneIndex = row(for: articleID) else {
				return
			}
			if oneIndex != NSNotFound {
				indexes.insert(oneIndex)
			}
		}
		
		return indexes
	}
	
	func selectFeed(_ indexPath: IndexPath) {
		if navControllerForTimeline().viewControllers.filter({ $0 is MasterTimelineViewController }).count > 0 {
			currentMasterIndexPath = indexPath
		} else {
			masterTimelineViewController = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
			masterTimelineViewController!.coordinator = self
			currentMasterIndexPath = indexPath
			navControllerForTimeline().pushViewController(masterTimelineViewController!, animated: true)
		}
		
		selectArticle(nil)
	}
	
	func selectArticle(_ indexPath: IndexPath?) {
		currentArticleIndexPath = indexPath
		ActivityManager.shared.reading(currentArticle)
		
		if indexPath == nil {
			if !rootSplitViewController.isCollapsed {
				let systemMessageViewController = UIStoryboard.main.instantiateController(ofType: SystemMessageViewController.self)
				installDetailController(systemMessageViewController)
			}
			return
		}
		
		if detailViewController == nil {
			let detailViewController = UIStoryboard.main.instantiateController(ofType: DetailViewController.self)
			detailViewController.coordinator = self
			installDetailController(detailViewController)
		}
		
		// Automatically hide the overlay
		if rootSplitViewController.displayMode == .primaryOverlay {
			UIView.animate(withDuration: 0.3) {
				self.rootSplitViewController.preferredDisplayMode = .primaryHidden
			}
			rootSplitViewController.preferredDisplayMode = .automatic
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
		selectFirstUnreadArticleInTimeline()
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
		
		selectNextUnreadFeedFetcher()
		selectNextUnreadArticleInTimeline()
		
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
	
	func markAsReadOlderArticlesInTimeline(_ indexPath: IndexPath) {
		let article = articles[indexPath.row]
		let articlesToMark = articles.filter { $0.logicalDatePublished < article.logicalDatePublished }
		if articlesToMark.isEmpty {
			return
		}
		markAllAsRead(articlesToMark)
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

	func toggleStarForCurrentArticle() {
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

	func discloseFeed(_ feed: Feed) {
		masterNavigationController.popViewController(animated: true)
		masterFeedViewController.discloseFeed(feed)
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
	
	func showAdd() {
		let addViewController = UIStoryboard.add.instantiateInitialViewController()!
		addViewController.modalPresentationStyle = .formSheet
		addViewController.preferredContentSize = AddContainerViewController.preferredContentSizeForFormSheetDisplay
		masterFeedViewController.present(addViewController, animated: true)
	}
	
	func showBrowser(for indexPath: IndexPath) {
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
	
}

// MARK: UISplitViewControllerDelegate

extension AppCoordinator: UISplitViewControllerDelegate {

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

// MARK: Private

private extension AppCoordinator {

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
	
	// MARK: Select Next Unread

	@discardableResult
	func selectFirstUnreadArticleInTimeline() -> Bool {
		return selectArticleInTimeline(startingRow: 0)
	}
	
	@discardableResult
	func selectNextUnreadArticleInTimeline() -> Bool {
		let startingRow: Int = {
			if let indexPath = currentArticleIndexPath {
				return indexPath.row
			} else {
				return 0
			}
		}()
		
		return selectArticleInTimeline(startingRow: startingRow)
	}
	
	func selectArticleInTimeline(startingRow: Int) -> Bool {
		
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
		
		guard let indexPath = currentMasterIndexPath else {
			assertionFailure()
			return
		}
		
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
			
			for j in indexPath.row..<shadowTable[indexPath.section].count {
				
				let nextIndexPath = IndexPath(row: j, section: i)
				guard let node = nodeFor(nextIndexPath), let unreadCountProvider = node.representedObject as? UnreadCountProvider else {
					assertionFailure()
					return true
				}
				
				if expandedNodes.contains(node) {
					continue
				}
				
				if unreadCountProvider.unreadCount > 0 {
					currentMasterIndexPath = nextIndexPath
					return true
				}
				
			}
			
		}
		
		return false
		
	}
	
	// MARK: Fetching Articles
	
	func emptyTheTimeline() {
		if !articles.isEmpty {
			articles = [Article]()
		}
	}
	
	func sortDirectionDidChange() {
		replaceArticles(with: Set(articles))
	}
	
	func replaceArticles(with unsortedArticles: Set<Article>) {
		let sortedArticles = Array(unsortedArticles).sortedByDate(sortDirection)
		if articles != sortedArticles {
			articles = sortedArticles
		}
	}
	
	func row(for articleID: String) -> Int? {
		updateArticleRowMapIfNeeded()
		return articleRowMap[articleID]
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

			strongSelf.replaceArticles(with: updatedArticles)
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
		replaceArticles(with: fetchedArticles)
	}

	func fetchAndReplaceArticlesAsync() {
		// To be called when we need to do an entire fetch, but an async delay is okay.
		// Example: we have the Today feed selected, and the calendar day just changed.
		cancelPendingAsyncFetches()
		guard let timelineFetcher = timelineFetcher else {
			emptyTheTimeline()
			return
		}
		fetchUnsortedArticlesAsync(for: [timelineFetcher]) { [weak self] (articles) in
			self?.replaceArticles(with: articles)
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
	
	func installDetailController(_ detailController: UIViewController) {
		let showButton = rootSplitViewController.displayMode != .allVisible
		let controller = addNavControllerIfNecessary(detailController, showButton: showButton)
		
		if isThreePanelMode {
			let targetSplit = ensureDoubleSplit().children.first as! UISplitViewController
			targetSplit.showDetailViewController(controller, sender: self)
		} else if rootSplitViewController.isCollapsed {
			rootSplitViewController.showDetailViewController(controller, sender: self)
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

		if currentMasterIndexPath == nil && currentArticleIndexPath == nil {
			
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
			ActivityManager.shared.selectingToday()
		case node.representedObject === SmartFeedsController.shared.unreadFeed:
			ActivityManager.shared.selectingAllUnread()
		case node.representedObject === SmartFeedsController.shared.starredFeed:
			ActivityManager.shared.selectingStarred()
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
	
	func handleReadArticle(_ activity: NSUserActivity) {
		guard let accountNode = findAccountNode(for: activity), let feedNode = findFeedNode(for: activity, beginningAt: accountNode) else {
			return
		}
		
		masterFeedViewController.discloseFeed(feedNode.representedObject as! Feed)
		
		guard let articleID = activity.userInfo?[ActivityID.articleID.rawValue] as? String else { return }
		
		for (index, article) in articles.enumerated() {
			if article.articleID == articleID {
				selectArticle(IndexPath(row: index, section: 0))
				break
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
