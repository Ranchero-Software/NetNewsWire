//
//  TimelineModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Combine
import RSCore
import Account
import Articles

protocol TimelineModelDelegate: class {
	var selectedFeeds: Published<[Feed]>.Publisher { get }
	func timelineRequestedWebFeedSelection(_: TimelineModel, webFeed: WebFeed)
}

class TimelineModel: ObservableObject, UndoableCommandRunner {
	
	weak var delegate: TimelineModelDelegate?
	
	@Published var nameForDisplay = ""
	@Published var selectedArticleIDs = Set<String>()  // Don't use directly.  Use selectedArticles
	@Published var selectedArticleID: String? = nil    // Don't use directly.  Use selectedArticles
	@Published var selectedArticles = [Article]()
	@Published var selectedTimelineItems = [TimelineItem]()
	@Published var readFilterEnabledTable = [FeedIdentifier: Bool]()
	@Published var isReadFiltered: Bool? = nil

	@Published var articles = [Article]() {
		didSet {
			articleDictionaryNeedsUpdate = true
		}
	}
	
	@Published var timelineItems = [TimelineItem]() {
		didSet {
			timelineItemDictionaryNeedsUpdate = true
		}
	}

	// I don't like this flag and feel like it is a hack.  Maybe there is a better way to do this using Combine.
	var isSelectNextUnread = false
	
	var undoManager: UndoManager?
	var undoableCommands = [UndoableCommand]()

	private var cancellables = Set<AnyCancellable>()

	private var feeds = [Feed]()
	private var fetchSerialNumber = 0
	private let fetchRequestQueue = FetchRequestQueue()
	private var exceptionArticleFetcher: ArticleFetcher?

	static let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5, maxInterval: 2.0)

	private var articleDictionaryNeedsUpdate = true
	private var _idToArticleDictionary = [String: Article]()
	private var idToArticleDictionary: [String: Article] {
		if articleDictionaryNeedsUpdate {
			rebuildArticleDictionaries()
		}
		return _idToArticleDictionary
	}

	private var timelineItemDictionaryNeedsUpdate = true
	private var _idToTimelineItemDictionary = [String: Int]()
	private var idToTimelineItemDictionary: [String: Int] {
		if timelineItemDictionaryNeedsUpdate {
			rebuildTimelineItemDictionaries()
		}
		return _idToTimelineItemDictionary
	}

	private var sortDirection = AppDefaults.shared.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortParametersDidChange()
			}
		}
	}
	
	private var groupByFeed = AppDefaults.shared.timelineGroupByFeed {
		didSet {
			if groupByFeed != oldValue {
				sortParametersDidChange()
			}
		}
	}
	
	func startup() {
		subscribeToArticleStatusChanges()
		subscribeToUserDefaultsChanges()
		subscribeToSelectedFeedChanges()
		subscribeToSelectedArticleSelectionChanges()
		subscribeToAccountDidDownloadArticles()
	}
	
	// MARK: Subscriptions
	
	func subscribeToArticleStatusChanges() {
		NotificationCenter.default.publisher(for: .StatusesDidChange).sink { [weak self] note in
			guard let self = self, let articleIDs = note.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String> else {
				return
			}
			articleIDs.forEach { articleID in
				if let timelineItemIndex = self.idToTimelineItemDictionary[articleID] {
					self.timelineItems[timelineItemIndex].updateStatus()
				}
			}
		}.store(in: &cancellables)
	}
	
	func subscribeToAccountDidDownloadArticles() {
		NotificationCenter.default.publisher(for: .AccountDidDownloadArticles).sink { [weak self] note in
			guard let self = self, let feeds = note.userInfo?[Account.UserInfoKey.webFeeds] as? Set<WebFeed> else {
				return
			}
			if self.anySelectedFeedIntersection(with: feeds) || self.anySelectedFeedIsPseudoFeed() {
				self.queueFetchAndMergeArticles()
			}
		}.store(in: &cancellables)
	}
	
	func subscribeToUserDefaultsChanges() {
		NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).sink { [weak self] _ in
			self?.sortDirection = AppDefaults.shared.timelineSortDirection
			self?.groupByFeed = AppDefaults.shared.timelineGroupByFeed
		}.store(in: &cancellables)
	}
	
	func subscribeToSelectedFeedChanges() {
		delegate?.selectedFeeds.sink { [weak self] feeds in
			guard let self = self else { return }
			self.feeds = feeds
			self.fetchArticles()
		}.store(in: &cancellables)
	}
	
	func subscribeToSelectedArticleSelectionChanges() {
		$selectedArticleIDs.map { [weak self] articleIDs in
			return articleIDs.compactMap { self?.idToArticleDictionary[$0] }
		}
		.assign(to: &$selectedArticles)
		
		$selectedArticleID.compactMap { [weak self] articleID in
			if let articleID = articleID, let article = self?.idToArticleDictionary[articleID] {
				return [article]
			} else {
				return nil
			}
		}
		.assign(to: &$selectedArticles)

		// Assign the selected timeline items
		$selectedArticles.compactMap { [weak self] selectedArticles in
			return selectedArticles.compactMap {
				if let index = self?.idToTimelineItemDictionary[$0.articleID] {
					return self?.timelineItems[index]
				}
				return nil
			}
		}.assign(to: &$selectedTimelineItems)
		
		// Automatically mark a selected record as read
		$selectedArticles
			.filter { $0.count == 1 }
			.compactMap { $0.first }
			.filter { !$0.status.read }
			.sink {	markArticles(Set([$0]), statusKey: .read, flag: true) }
			.store(in: &cancellables)
	}
	
	// MARK: API
	
	func toggleReadFilter() {
		guard let filter = isReadFiltered, let feedID = feeds.first?.feedID else { return }
		readFilterEnabledTable[feedID] = !filter
		isReadFiltered = !filter
		self.fetchArticles()
	}
	
	func toggleReadStatusForSelectedArticles() {
		guard !selectedArticles.isEmpty else {
			return
		}
		if selectedArticles.anyArticleIsUnread() {
			markSelectedArticlesAsRead()
		} else {
			markSelectedArticlesAsUnread()
		}
	}

	func canMarkIndicatedArticlesAsRead(_ timelineItem: TimelineItem) -> Bool {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		return articles.anyArticleIsUnread()
	}

	func markIndicatedArticlesAsRead(_ timelineItem: TimelineItem) {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		markArticlesWithUndo(articles, statusKey: .read, flag: true)
	}
	
	func markSelectedArticlesAsRead() {
		markArticlesWithUndo(selectedArticles, statusKey: .read, flag: true)
	}
	
	func canMarkIndicatedArticlesAsUnread(_ timelineItem: TimelineItem) -> Bool {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		return articles.anyArticleIsReadAndCanMarkUnread()
	}

	func markIndicatedArticlesAsUnread(_ timelineItem: TimelineItem) {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		markArticlesWithUndo(articles, statusKey: .read, flag: false)
	}
	
	func markSelectedArticlesAsUnread() {
		markArticlesWithUndo(selectedArticles, statusKey: .read, flag: false)
	}
	
	func canMarkAboveAsRead(_ timelineItem: TimelineItem) -> Bool {
		let timelineItem = indicatedAboveTimelineItem(timelineItem)
		return articles.articlesAbove(position: timelineItem.index).canMarkAllAsRead()
	}

	func markAboveAsRead(_ timelineItem: TimelineItem) {
		let timelineItem = indicatedAboveTimelineItem(timelineItem)
		let articlesToMark = articles.articlesAbove(position: timelineItem.index)
		guard !articlesToMark.isEmpty else { return }
		markArticlesWithUndo(articlesToMark, statusKey: .read, flag: true)
	}

	func canMarkBelowAsRead(_ timelineItem: TimelineItem) -> Bool {
		let timelineItem = indicatedBelowTimelineItem(timelineItem)
		return articles.articlesBelow(position: timelineItem.index).canMarkAllAsRead()
	}

	func markBelowAsRead(_ timelineItem: TimelineItem) {
		let timelineItem = indicatedBelowTimelineItem(timelineItem)
		let articlesToMark = articles.articlesBelow(position: timelineItem.index)
		guard !articlesToMark.isEmpty else { return }
		markArticlesWithUndo(articlesToMark, statusKey: .read, flag: true)
	}
	
	func canMarkAllAsReadInWebFeed(_ timelineItem: TimelineItem) -> Bool {
		return timelineItem.article.webFeed?.unreadCount ?? 0 > 0
	}
	
	func markAllAsReadInWebFeed(_ timelineItem: TimelineItem) {
		guard let articlesSet = try? timelineItem.article.webFeed?.fetchArticles() else { return	}
		let articlesToMark = Array(articlesSet)
		markArticlesWithUndo(articlesToMark, statusKey: .read, flag: true)
	}
	
	func canMarkAllAsRead() -> Bool {
		return articles.canMarkAllAsRead()
	}
	
	func markAllAsRead() {
		markArticlesWithUndo(articles, statusKey: .read, flag: true)
	}

	func toggleStarredStatusForSelectedArticles() {
		guard !selectedArticles.isEmpty else {
			return
		}
		if selectedArticles.anyArticleIsUnstarred() {
			markSelectedArticlesAsStarred()
		} else {
			markSelectedArticlesAsUnstarred()
		}
	}

	func canMarkIndicatedArticlesAsStarred(_ timelineItem: TimelineItem) -> Bool {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		return articles.anyArticleIsUnstarred()
	}

	func markIndicatedArticlesAsStarred(_ timelineItem: TimelineItem) {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		markArticlesWithUndo(articles, statusKey: .starred, flag: true)
	}

	func markSelectedArticlesAsStarred() {
		markArticlesWithUndo(selectedArticles, statusKey: .starred, flag: true)
	}
	
	func canMarkIndicatedArticlesAsUnstarred(_ timelineItem: TimelineItem) -> Bool {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		return articles.anyArticleIsStarred()
	}

	func markIndicatedArticlesAsUnstarred(_ timelineItem: TimelineItem) {
		let articles = indicatedTimelineItems(timelineItem).map { $0.article }
		markArticlesWithUndo(articles, statusKey: .starred, flag: false)
	}

	func markSelectedArticlesAsUnstarred() {
		markArticlesWithUndo(selectedArticles, statusKey: .starred, flag: false)
	}
	
	func canOpenIndicatedArticleInBrowser(_ timelineItem: TimelineItem) -> Bool {
		guard indicatedTimelineItems(timelineItem).count == 1 else { return false }
		return timelineItem.article.preferredLink != nil
	}
	
	func openIndicatedArticleInBrowser(_ timelineItem: TimelineItem) {
		openIndicatedArticleInBrowser(timelineItem.article)
	}
	
	func openIndicatedArticleInBrowser(_ article: Article) {
		guard let link = article.preferredLink else { return }
		
		#if os(macOS)
		Browser.open(link, invertPreference: NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false)
		#else
		guard let url = URL(string: link) else { return }
		UIApplication.shared.open(url, options: [:])
		#endif
	}
	
	func openSelectedArticleInBrowser() {
		guard let article = selectedArticles.first else { return }
		openIndicatedArticleInBrowser(article)
	}

	@discardableResult
	func goToNextUnread() -> Bool {
		var startIndex: Int
		if let firstArticle = selectedArticles.first, let index = timelineItems.firstIndex(where: { $0.article == firstArticle }) {
			startIndex = index
		} else {
			startIndex = 0
		}
		
		for i in startIndex..<timelineItems.count {
			if !timelineItems[i].article.status.read {
				select(timelineItems[i].article.articleID)
				return true
			}
		}
		
		return false
	}

	func articleFor(_ articleID: String) -> Article? {
		return idToArticleDictionary[articleID]
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
	
	func selectArticle(_ article: Article) {
		// TODO: Implement me!
	}
	
}

// MARK: Private

private extension TimelineModel {
	
	func indicatedTimelineItems(_ timelineItem: TimelineItem) -> [TimelineItem] {
		if selectedTimelineItems.contains(where: { $0.id == timelineItem.id }) {
			return selectedTimelineItems
		} else {
			return [timelineItem]
		}
	}
	
	func indicatedAboveTimelineItem(_ timelineItem: TimelineItem) -> TimelineItem {
		if selectedTimelineItems.contains(where: { $0.id == timelineItem.id }) {
			return selectedTimelineItems.first!
		} else {
			return timelineItem
		}
	}
	
	func indicatedBelowTimelineItem(_ timelineItem: TimelineItem) -> TimelineItem {
		if selectedTimelineItems.contains(where: { $0.id == timelineItem.id }) {
			return selectedTimelineItems.last!
		} else {
			return timelineItem
		}
	}
	
	func markArticlesWithUndo(_ articles: [Article], statusKey: ArticleStatus.Key, flag: Bool) {
		if let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: articles, statusKey: statusKey, flag: flag, undoManager: undoManager) {
			runCommand(markReadCommand)
		} else {
			markArticles(Set(articles), statusKey: statusKey, flag: flag)
		}
	}
	
	func select(_ articleID: String) {
		selectedArticleIDs = Set([articleID])
		selectedArticleID = articleID
	}
	
	// MARK: Timeline Management
	
	func resetReadFilter() {
		guard feeds.count == 1, let timelineFeed = feeds.first else {
			isReadFiltered = nil
			return
		}
		
		guard timelineFeed.defaultReadFilterType != .alwaysRead else {
			isReadFiltered = nil
			return
		}
		
		if let feedID = timelineFeed.feedID, let readFilterEnabled = readFilterEnabledTable[feedID] {
			isReadFiltered =  readFilterEnabled
		} else {
			isReadFiltered = timelineFeed.defaultReadFilterType == .read
		}
	}

	func sortParametersDidChange() {
		performBlockAndRestoreSelection {
			articles = articles.sortedByDate(sortDirection ? .orderedDescending : .orderedAscending, groupByFeed: groupByFeed)
			rebuildTimelineItems()
		}
	}
	
	func performBlockAndRestoreSelection(_ block: (() -> Void)) {
		let savedArticleIDs = selectedArticleIDs
		let savedArticleID = selectedArticleID
		block()
		selectedArticleIDs = savedArticleIDs
		selectedArticleID = savedArticleID
	}

	func rebuildArticleDictionaries() {
		var idDictionary = [String: Article]()
		articles.forEach { article in
			idDictionary[article.articleID] = article
		}
		_idToArticleDictionary = idDictionary
		articleDictionaryNeedsUpdate = false
	}
	
	func rebuildTimelineItemDictionaries() {
		var idDictionary = [String: Int]()
		for (index, timelineItem) in timelineItems.enumerated() {
			idDictionary[timelineItem.article.articleID] = index
		}
		_idToTimelineItemDictionary = idDictionary
		timelineItemDictionaryNeedsUpdate = false
	}
	
	// MARK: Article Fetching
	
	func fetchArticles() {
		replaceArticles(with: Set<Article>())

		guard !feeds.isEmpty else {
			nameForDisplay = ""
			return
		}
		
		if feeds.count == 1 {
			nameForDisplay = feeds.first!.nameForDisplay
		} else {
			nameForDisplay = NSLocalizedString("Multiple", comment: "Multiple Feeds")
		}
		
		resetReadFilter()
		
		#if os(macOS)
		fetchAndReplaceArticlesSync()
		#else
		fetchAndReplaceArticlesAsync()
		#endif
	}
	
	func fetchAndReplaceArticlesSync() {
		// To be called when the user has made a change of selection in the sidebar.
		// It blocks the main thread, so that there’s no async delay,
		// so that the entire display refreshes at once.
		// It’s a better user experience this way.
		var fetchers = feeds as [ArticleFetcher]
		if let fetcher = exceptionArticleFetcher {
			fetchers.append(fetcher)
			exceptionArticleFetcher = nil
		}
		
		let fetchedArticles = fetchUnsortedArticlesSync(for: fetchers)
		replaceArticles(with: fetchedArticles)
	}

	func fetchAndReplaceArticlesAsync() {
		var fetchers = feeds as [ArticleFetcher]
		if let fetcher = exceptionArticleFetcher {
			fetchers.append(fetcher)
			exceptionArticleFetcher = nil
		}
		
		fetchUnsortedArticlesAsync(for: fetchers) { [weak self] (articles) in
			self?.replaceArticles(with: articles)
		}
	}

	func cancelPendingAsyncFetches() {
		fetchSerialNumber += 1
		fetchRequestQueue.cancelAllRequests()
	}

	func fetchUnsortedArticlesSync(for representedObjects: [Any]) -> Set<Article> {
		cancelPendingAsyncFetches()
		let articleFetchers = representedObjects.compactMap{ $0 as? ArticleFetcher }
		if articleFetchers.isEmpty {
			return Set<Article>()
		}

		var fetchedArticles = Set<Article>()
		for articleFetcher in articleFetchers {
			if isReadFiltered ?? true {
				if let articles = try? articleFetcher.fetchUnreadArticles() {
					fetchedArticles.formUnion(articles)
				}
			} else {
				if let articles = try? articleFetcher.fetchArticles() {
					fetchedArticles.formUnion(articles)
				}
			}
		}
		return fetchedArticles
	}
	
	func fetchUnsortedArticlesAsync(for representedObjects: [Any], completion: @escaping ArticleSetBlock) {
		// The callback will *not* be called if the fetch is no longer relevant — that is,
		// if it’s been superseded by a newer fetch, or the timeline was emptied, etc., it won’t get called.
		precondition(Thread.isMainThread)
		cancelPendingAsyncFetches()

		let filtered = isReadFiltered ?? false
		let fetchOperation = FetchRequestOperation(id: fetchSerialNumber, readFilter: filtered, representedObjects: representedObjects) { [weak self] (articles, operation) in
			precondition(Thread.isMainThread)
			guard !operation.isCanceled, let strongSelf = self, operation.id == strongSelf.fetchSerialNumber else {
				return
			}
			completion(articles)
		}
		fetchRequestQueue.add(fetchOperation)
	}
	
	func replaceArticles(with unsortedArticles: Set<Article>) {
		articles = Array(unsortedArticles).sortedByDate(sortDirection ? .orderedDescending : .orderedAscending, groupByFeed: groupByFeed)
		rebuildTimelineItems()
		
		selectedArticleIDs = Set<String>()
		selectedArticleID = nil
		
		if isSelectNextUnread {
			goToNextUnread()
			isSelectNextUnread = false
		}
		
		// TODO: Update unread counts and other item done in didSet on AppKit
	}
	
	func rebuildTimelineItems() {
		var items = [TimelineItem]()
		for (index, article) in articles.enumerated() {
			items.append(TimelineItem(index: index, article: article))
		}
		timelineItems = items
	}

	func queueFetchAndMergeArticles() {
		TimelineModel.fetchAndMergeArticlesQueue.add(self, #selector(fetchAndMergeArticles))
	}
	
	@objc func fetchAndMergeArticles() {
		
		fetchUnsortedArticlesAsync(for: feeds) { [weak self] (unsortedArticles) in
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
			strongSelf.performBlockAndRestoreSelection {
				strongSelf.replaceArticles(with: updatedArticles)
			}
		}
	}
	
	func anySelectedFeedIsPseudoFeed() -> Bool {
		return feeds.contains(where: { $0 is PseudoFeed})
	}
	
	func anySelectedFeedIntersection(with webFeeds: Set<WebFeed>) -> Bool {
		for feed in feeds {
			if let selectedWebFeed = feed as? WebFeed {
				for webFeed in webFeeds {
					if selectedWebFeed.webFeedID == webFeed.webFeedID || selectedWebFeed.url == webFeed.url {
						return true
					}
				}
			} else if let folder = feed as? Folder {
				for webFeed in webFeeds {
					if folder.hasWebFeed(with: webFeed.webFeedID) || folder.hasWebFeed(withURL: webFeed.url) {
						return true
					}
				}
			}
		}
		return false
	}
}
