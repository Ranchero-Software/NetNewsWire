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

// TODO: unify these two versions of FetchRequestOperation,
// which diverged when we changed — just on iOS — how we keep track
// of sidebar item hide-read-articles settings.

#if os(macOS)

@MainActor final class FetchRequestOperation {

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

		Task { @MainActor in
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

			@MainActor func process(_ articles: Set<Article>) {
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

			for fetcher in fetchers {
				if (fetcher as? SidebarItem)?.readFiltered(readFilterEnabledTable: readFilterEnabledTable) ?? true {
					if let articles = try? await fetcher.fetchUnreadArticlesAsync() {
						process(articles)
					}
				} else {
					if let articles = try? await fetcher.fetchArticlesAsync() {
						process(articles)
					}
				}
			}
		}
	}
}

#else

@MainActor final class FetchRequestOperation {

	let id: Int
	let hidingReadArticlesState: HidingReadArticlesState
	let resultBlock: FetchRequestOperationResultBlock
	var isCanceled = false
	var isFinished = false
	private let fetchers: [ArticleFetcher]

	init(id: Int, hidingReadArticlesState: HidingReadArticlesState, fetchers: [ArticleFetcher], resultBlock: @escaping FetchRequestOperationResultBlock) {
		precondition(Thread.isMainThread)
		self.id = id
		self.hidingReadArticlesState = hidingReadArticlesState
		self.fetchers = fetchers
		self.resultBlock = resultBlock
	}

	@MainActor func run(_ completion: @escaping (FetchRequestOperation) -> Void) {
		precondition(Thread.isMainThread)
		precondition(!isFinished)

		Task { @MainActor in
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

			@MainActor func process(_ articles: Set<Article>) {
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

			@MainActor func fetcherHidesReadArticles(_ fetcher: ArticleFetcher) -> Bool {
				guard let sidebarItem = fetcher as? SidebarItem, let sidebarItemID = sidebarItem.sidebarItemID else {
					return false
				}
				return hidingReadArticlesState.isHidingReadArticles(for: sidebarItemID)
			}

			for fetcher in fetchers {
				if fetcherHidesReadArticles(fetcher) {
					if let articles = try? await fetcher.fetchUnreadArticlesAsync() {
						process(articles)
					}
				} else {
					if let articles = try? await fetcher.fetchArticlesAsync() {
						process(articles)
					}
				}
			}
		}
	}
}

#endif
