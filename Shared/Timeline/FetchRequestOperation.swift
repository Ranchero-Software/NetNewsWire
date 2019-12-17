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
	let readFilter: Bool
	let resultBlock: FetchRequestOperationResultBlock
	var isCanceled = false
	var isFinished = false
	private let representedObjects: [Any]

	init(id: Int, readFilter: Bool, representedObjects: [Any], resultBlock: @escaping FetchRequestOperationResultBlock) {
		precondition(Thread.isMainThread)
		self.id = id
		self.readFilter = readFilter
		self.representedObjects = representedObjects
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

		let articleFetchers = representedObjects.compactMap{ $0 as? ArticleFetcher }
		if articleFetchers.isEmpty {
			isFinished = true
			resultBlock(Set<Article>(), self)
			callCompletionIfNeeded()
			return
		}

		let numberOfFetchers = articleFetchers.count
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
		
		for articleFetcher in articleFetchers {
			if readFilter {
				articleFetcher.fetchUnreadArticlesAsync { articleSetResult in
					let articles = (try? articleSetResult.get()) ?? Set<Article>()
					process(articles)
				}
			}
			else {
				articleFetcher.fetchArticlesAsync { articleSetResult in
					let articles = (try? articleSetResult.get()) ?? Set<Article>()
					process(articles)
				}
			}
		}
	}
}

