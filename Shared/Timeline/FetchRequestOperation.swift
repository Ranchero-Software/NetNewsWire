//
//  FetchRequestOperation.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account
import Articles

// Main thread only.
// Runs an asynchronous fetch.

typealias FetchRequestOperationResultBlock = (Set<Article>, FetchRequestOperation) -> Void

final class FetchRequestOperation {

	let id: Int
	let readFilterEnabledTable: [FeedIdentifier: Bool]
	let resultBlock: FetchRequestOperationResultBlock
	var isCanceled = false
	var isFinished = false
	private let feeds: [Feed]

	init(id: Int, readFilterEnabledTable: [FeedIdentifier: Bool], feeds: [Feed], resultBlock: @escaping FetchRequestOperationResultBlock) {
		precondition(Thread.isMainThread)
		self.id = id
		self.readFilterEnabledTable = readFilterEnabledTable
		self.feeds = feeds
		self.resultBlock = resultBlock
	}

	func run(_ completion: @escaping (FetchRequestOperation) -> Void) {
		precondition(Thread.isMainThread)
		precondition(!isFinished)

		var didCallCompletion = false

		func callCompletionIfNeeded() {
			if !didCallCompletion {
				didCallCompletion = true
				completion(self)
			}
		}

		if isCanceled {
			callCompletionIfNeeded()
			return
		}

		if feeds.isEmpty {
			isFinished = true
			resultBlock(Set<Article>(), self)
			callCompletionIfNeeded()
			return
		}

		let numberOfFetchers = feeds.count
		var fetchersReturned = 0
		var fetchedArticles = Set<Article>()
		
		func process(_ articles: Set<Article>) {
			precondition(Thread.isMainThread)
			guard !self.isCanceled else {
				callCompletionIfNeeded()
				return
			}
			
			assert(!self.isFinished)

			fetchedArticles.formUnion(articles)
			fetchersReturned += 1
			if fetchersReturned == numberOfFetchers {
				self.isFinished = true
				self.resultBlock(fetchedArticles, self)
				callCompletionIfNeeded()
			}
		}
		
		for feed in feeds {
			if feed.readFiltered(readFilterEnabledTable: readFilterEnabledTable) {
				feed.fetchUnreadArticlesAsync { articleSetResult in
					let articles = (try? articleSetResult.get()) ?? Set<Article>()
					process(articles)
				}
			}
			else {
				feed.fetchArticlesAsync { articleSetResult in
					let articles = (try? articleSetResult.get()) ?? Set<Article>()
					process(articles)
				}
			}
		}
	}
}

