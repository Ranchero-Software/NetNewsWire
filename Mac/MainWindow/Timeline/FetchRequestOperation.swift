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

class FetchRequestOperation {

	let id: Int
	let resultBlock: FetchRequestOperationResultBlock
	var isCanceled = false
	var isFinished = false
	private let representedObjects: [Any]

	init(id: Int, representedObjects: [Any], resultBlock: @escaping FetchRequestOperationResultBlock) {
		precondition(Thread.isMainThread)
		self.id = id
		self.representedObjects = representedObjects
		self.resultBlock = resultBlock
	}

	func run(_ completion: @escaping (FetchRequestOperation) -> Void) {
		precondition(Thread.isMainThread)
		precondition(!isFinished)

		if isCanceled {
			completion(self)
			return
		}

		let articleFetchers = representedObjects.compactMap{ $0 as? ArticleFetcher }
		if articleFetchers.isEmpty {
			isFinished = true
			resultBlock(Set<Article>(), self)
			completion(self)
			return
		}

		let numberOfFetchers = articleFetchers.count
		var fetchersReturned = 0
		var fetchedArticles = Set<Article>()
		for articleFetcher in articleFetchers {
			var didCallCompletion = false
			articleFetcher.fetchArticlesAsync { (articles) in
				precondition(Thread.isMainThread)
				if self.isCanceled {
					if !didCallCompletion {
						didCallCompletion = true
						completion(self)
					}
					return
				}
				fetchedArticles.formUnion(articles)
				fetchersReturned += 1
				if fetchersReturned == numberOfFetchers {
					self.isFinished = true
					self.resultBlock(fetchedArticles, self)
					completion(self)
				}
			}
		}
	}
}

