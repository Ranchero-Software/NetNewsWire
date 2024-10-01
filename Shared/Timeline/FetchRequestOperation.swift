//
//  FetchRequestOperation.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Articles

// Main thread only.
// Runs an asynchronous fetch.

typealias FetchRequestOperationResultBlock = (Set<Article>, FetchRequestOperation) -> Void

final class FetchRequestOperation {

	let id: Int
	let readFilterEnabledTable: [SidebarItemIdentifier: Bool]
	let resultBlock: FetchRequestOperationResultBlock
	var isCanceled = false
	var isFinished = false
	private let fetchers: [ArticleFetcher]

	init(id: Int, readFilterEnabledTable: [SidebarItemIdentifier: Bool], fetchers: [ArticleFetcher], resultBlock: @escaping FetchRequestOperationResultBlock) {
		precondition(Thread.isMainThread)
		self.id = id
		self.readFilterEnabledTable = readFilterEnabledTable
		self.fetchers = fetchers
		self.resultBlock = resultBlock
	}

	@MainActor func run(_ completion: @escaping (FetchRequestOperation) -> Void) {
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

		if fetchers.isEmpty {
			isFinished = true
			resultBlock(Set<Article>(), self)
			callCompletionIfNeeded()
			return
		}

		let numberOfFetchers = fetchers.count
		var fetchersReturned = 0
		var fetchedArticles = Set<Article>()
		
		func process(_ articles: Set<Article>?) {
			precondition(Thread.isMainThread)
			guard !self.isCanceled else {
				callCompletionIfNeeded()
				return
			}
			
			assert(!self.isFinished)

			if let articles {
				fetchedArticles.formUnion(articles)
			}

			fetchersReturned += 1
			if fetchersReturned == numberOfFetchers {
				self.isFinished = true
				self.resultBlock(fetchedArticles, self)
				callCompletionIfNeeded()
			}
		}
		
		Task { @MainActor in
			for fetcher in fetchers {
				if (fetcher as? SidebarItem)?.readFiltered(readFilterEnabledTable: readFilterEnabledTable) ?? true {
					let articles = try? await fetcher.fetchUnreadArticles()
					process(articles)
				} else {
					let articles = try? await fetcher.fetchArticles()
					process(articles)
				}
			}
		}
	}
}

