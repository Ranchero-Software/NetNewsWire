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
	
	private var articles = [Article]()
	
	private var sortDirection = AppDefaults.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortParametersDidChange()
			}
		}
	}
	
	private var groupByFeed = AppDefaults.timelineGroupByFeed {
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
		articles = Array(unsortedArticles).sortedByDate(sortDirection, groupByFeed: groupByFeed)
		timelineItems = articles.map { TimelineItem(article: $0) }
		
		// TODO: Update unread counts and other item done in didSet on AppKit
	}


	// MARK: - Notifications

}
