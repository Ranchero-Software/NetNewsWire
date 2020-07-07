//
//  TimelineModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account
import Articles

protocol TimelineModelDelegate: class {
	func timelineRequestedWebFeedSelection(_: TimelineModel, webFeed: WebFeed)
}

class TimelineModel: ObservableObject {
	
	weak var delegate: TimelineModelDelegate?
	
	@Published var timelineItems = [TimelineItem]()
	
	private var feeds = [Feed]()
	private var fetchSerialNumber = 0
	private let fetchRequestQueue = FetchRequestQueue()
	private var exceptionArticleFetcher: ArticleFetcher?
	private var isReadFiltered = false
	
	private var articles = [Article]() {
		didSet {
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
	
	init() {
	}
	
	// MARK: API
	
	func rebuildTimelineItems(_ feed: Feed) {
		feeds = [feed]
		fetchAndReplaceArticlesAsync()
	}
	
	// TODO: Replace this with ScrollViewReader if we have to keep it
	func loadMoreTimelineItemsIfNecessary(_ timelineItem: TimelineItem) {
		let thresholdIndex = timelineItems.index(timelineItems.endIndex, offsetBy: -10)
		if timelineItems.firstIndex(where: { $0.id == timelineItem.id }) == thresholdIndex {
			nextBatch()
		}
	}
	
	func articleFor(_ articleID: String) -> Article? {
		return idToAticleDictionary[articleID]
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
	
	func sortParametersDidChange() {
		performBlockAndRestoreSelection {
			let unsortedArticles = Set(articles)
			replaceArticles(with: unsortedArticles)
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
	
	func fetchAndReplaceArticlesAsync() {
		cancelPendingAsyncFetches()
		
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
		let fetchOperation = FetchRequestOperation(id: fetchSerialNumber, readFilter: isReadFiltered ?? true, representedObjects: representedObjects) { [weak self] (articles, operation) in
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
		timelineItems = [TimelineItem]()
		nextBatch()
		// TODO: Update unread counts and other item done in didSet on AppKit
	}

	func nextBatch() {
		let rangeEndIndex = timelineItems.endIndex + 50 > articles.endIndex ? articles.endIndex : timelineItems.endIndex + 50
		let range = timelineItems.endIndex..<rangeEndIndex
		for i in range {
			timelineItems.append(TimelineItem(article: articles[i]))
		}
	}
	
	// MARK: - Notifications

}
