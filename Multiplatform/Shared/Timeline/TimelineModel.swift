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
	@Published var timelineItems = [TimelineItem]()
	@Published var selectedArticleIDs = Set<String>()  // Don't use directly.  Use selectedArticles
	@Published var selectedArticleID: String? = .none  // Don't use directly.  Use selectedArticles
	@Published var selectedArticles = [Article]()
	@Published var readFilterEnabledTable = [FeedIdentifier: Bool]()
	@Published var isReadFiltered: Bool? = nil

	@Published var articles = [Article]() {
		didSet {
			articleDictionaryNeedsUpdate = true
		}
	}

	var undoManager: UndoManager?
	var undoableCommands = [UndoableCommand]()

	private var selectedFeedsCancellable: AnyCancellable?
	private var selectedArticleIDsCancellable: AnyCancellable?
	private var selectedArticleIDCancellable: AnyCancellable?
	private var selectedArticlesCancellable: AnyCancellable?

	private var feeds = [Feed]()
	private var fetchSerialNumber = 0
	private let fetchRequestQueue = FetchRequestQueue()
	private var exceptionArticleFetcher: ArticleFetcher?
		
	private var articleDictionaryNeedsUpdate = true
	private var _idToArticleDictionary = [String: Article]()
	private var idToArticleDictionary: [String: Article] {
		if articleDictionaryNeedsUpdate {
			rebuildArticleDictionaries()
		}
		return _idToArticleDictionary
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
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		
		// TODO: This should be rewritten to use Combine correctly
		selectedFeedsCancellable = delegate?.selectedFeeds.sink { [weak self] feeds in
			guard let self = self else { return }
			self.fetchArticles(feeds: feeds)
		}

		// TODO: This should be rewritten to use Combine correctly
		selectedArticleIDsCancellable = $selectedArticleIDs.sink { [weak self] articleIDs in
			guard let self = self else { return }
			self.selectedArticles = articleIDs.compactMap { self.idToArticleDictionary[$0] }
		}
		
		// TODO: This should be rewritten to use Combine correctly
		selectedArticleIDCancellable = $selectedArticleID.sink { [weak self] articleID in
			guard let self = self else { return }
			if let articleID = articleID, let article = self.idToArticleDictionary[articleID] {
				self.selectedArticles = [article]
			}
		}

		// TODO: This should be rewritten to use Combine correctly
		selectedArticlesCancellable = $selectedArticles.sink { articles in
			if articles.count == 1 {
				let article = articles.first!
				if !article.status.read {
					markArticles(Set([article]), statusKey: .read, flag: true)
				}
			}
		}
		
	}
	
	// MARK: API
	
	func toggleReadFilter() {
		guard let filter = isReadFiltered, let feedID = feeds.first?.feedID else { return }
		readFilterEnabledTable[feedID] = !filter
		isReadFiltered = !filter
		rebuildTimelineItems()
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

	func canMarkIndicatedArticlesAsRead(_ article: Article) -> Bool {
		let articles = indicatedArticles(article)
		return articles.anyArticleIsUnread()
	}

	func markIndicatedArticlesAsRead(_ article: Article) {
		let articles = indicatedArticles(article)
		markArticlesWithUndo(articles, statusKey: .read, flag: true)
	}
	
	func markSelectedArticlesAsRead() {
		markArticlesWithUndo(selectedArticles, statusKey: .read, flag: true)
	}
	
	func canMarkIndicatedArticlesAsUnread(_ article: Article) -> Bool {
		let articles = indicatedArticles(article)
		return articles.anyArticleIsReadAndCanMarkUnread()
	}

	func markIndicatedArticlesAsUnread(_ article: Article) {
		let articles = indicatedArticles(article)
		markArticlesWithUndo(articles, statusKey: .read, flag: false)
	}
	
	func markSelectedArticlesAsUnread() {
		markArticlesWithUndo(selectedArticles, statusKey: .read, flag: false)
	}
	
	func canMarkAboveAsRead(_ article: Article) -> Bool {
		let article = indicatedAboveArticle(article)
		return articles.articlesAbove(article: article).canMarkAllAsRead()
	}

	func markAboveAsRead(_ article: Article) {
		let article = indicatedAboveArticle(article)
		let articlesToMark = articles.articlesAbove(article: article)
		guard !articlesToMark.isEmpty else { return }
		markArticlesWithUndo(articlesToMark, statusKey: .read, flag: true)
	}

	func canMarkBelowAsRead(_ article: Article) -> Bool {
		let article = indicatedBelowArticle(article)
		return articles.articlesBelow(article: article).canMarkAllAsRead()
	}

	func markBelowAsRead(_ article: Article) {
		let article = indicatedBelowArticle(article)
		let articlesToMark = articles.articlesBelow(article: article)
		guard !articlesToMark.isEmpty else { return }
		markArticlesWithUndo(articlesToMark, statusKey: .read, flag: true)
	}
	
	func canMarkAllAsReadInFeed(_ feed: Feed) -> Bool {
		guard let articlesSet = try? feed.fetchArticles() else {
			return false
		}
		return Array(articlesSet).canMarkAllAsRead()
	}
	
	func markAllAsReadInFeed(_ feed: Feed) {
		guard let articlesSet = try? feed.fetchArticles() else { return	}
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

	func canMarkIndicatedArticlesAsStarred(_ article: Article) -> Bool {
		let articles = indicatedArticles(article)
		return articles.anyArticleIsUnstarred()
	}

	func markIndicatedArticlesAsStarred(_ article: Article) {
		let articles = indicatedArticles(article)
		markArticlesWithUndo(articles, statusKey: .starred, flag: true)
	}

	func markSelectedArticlesAsStarred() {
		markArticlesWithUndo(selectedArticles, statusKey: .starred, flag: true)
	}
	
	func canMarkIndicatedArticlesAsUnstarred(_ article: Article) -> Bool {
		let articles = indicatedArticles(article)
		return articles.anyArticleIsStarred()
	}

	func markIndicatedArticlesAsUnstarred(_ article: Article) {
		let articles = indicatedArticles(article)
		markArticlesWithUndo(articles, statusKey: .starred, flag: false)
	}

	func markSelectedArticlesAsUnstarred() {
		markArticlesWithUndo(selectedArticles, statusKey: .starred, flag: false)
	}
	
	func canOpenIndicatedArticleInBrowser(_ article: Article) -> Bool {
		guard indicatedArticles(article).count == 1 else { return false }
		return article.preferredLink != nil
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
	
	func indicatedArticles(_ article: Article) -> [Article] {
		if selectedArticles.contains(article) {
			return selectedArticles
		} else {
			return [article]
		}
	}
	
	func indicatedAboveArticle(_ article: Article) -> Article {
		if selectedArticles.contains(article) {
			return selectedArticles.first!
		} else {
			return article
		}
	}
	
	func indicatedBelowArticle(_ article: Article) -> Article {
		if selectedArticles.contains(article) {
			return selectedArticles.last!
		} else {
			return article
		}
	}
	
	func markArticlesWithUndo(_ articles: [Article], statusKey: ArticleStatus.Key, flag: Bool) {
		guard let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: articles, statusKey: statusKey, flag: flag, undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}
	
	// MARK: Notifications

	@objc func statusesDidChange(_ note: Notification) {
		guard let articleIDs = note.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String> else {
			return
		}
		for i in 0..<timelineItems.count {
			if articleIDs.contains(timelineItems[i].article.articleID) {
				timelineItems[i].updateStatus()
			}
		}
	}
	
	@objc func userDefaultsDidChange(_ note: Notification) {
		sortDirection = AppDefaults.shared.timelineSortDirection
		groupByFeed = AppDefaults.shared.timelineGroupByFeed
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
//		let savedSelection = selectedArticleIDs()
		block()
//		restoreSelection(savedSelection)
	}

	func rebuildArticleDictionaries() {
		var idDictionary = [String: Article]()
		articles.forEach { article in
			idDictionary[article.articleID] = article
		}
		_idToArticleDictionary = idDictionary
		articleDictionaryNeedsUpdate = false
	}
	
	// MARK: Article Fetching
	
	func fetchArticles(feeds: [Feed]) {
		self.feeds = feeds
		
		if feeds.count == 1 {
			nameForDisplay = feeds.first!.nameForDisplay
		} else {
			nameForDisplay = NSLocalizedString("Multiple", comment: "Multiple Feeds")
		}
		
		resetReadFilter()
		fetchAndReplaceArticlesAsync()
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

	func fetchUnsortedArticlesAsync(for representedObjects: [Any], completion: @escaping ArticleSetBlock) {
		// The callback will *not* be called if the fetch is no longer relevant — that is,
		// if it’s been superseded by a newer fetch, or the timeline was emptied, etc., it won’t get called.
		precondition(Thread.isMainThread)
		cancelPendingAsyncFetches()

		// Right now we are pulling all the records and filtering them in the UI.  This is because the async
		// change of the timeline times doesn't trigger an animation because it isn't in a withAnimation block.
		// Ideally this would be done in the database tier with a query, but if you look, we always pull everything
		// from SQLite and filter it programmatically at that level currently.  So no big deal.
		// We should change this as soon as we figure out how to trigger animations on Lists with async tasks.
		let fetchOperation = FetchRequestOperation(id: fetchSerialNumber, readFilter: false, representedObjects: representedObjects) { [weak self] (articles, operation) in
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
		// TODO: Update unread counts and other item done in didSet on AppKit
	}
	
	func rebuildTimelineItems() {
		let filtered = isReadFiltered ?? false
		let selectedArticleIDs = selectedArticles.map { $0.articleID }

		timelineItems = articles.compactMap { article in
			if filtered && article.status.read && !selectedArticleIDs.contains(article.articleID) {
				return nil
			} else {
				return TimelineItem(article: article)
			}
		}
	}

}
