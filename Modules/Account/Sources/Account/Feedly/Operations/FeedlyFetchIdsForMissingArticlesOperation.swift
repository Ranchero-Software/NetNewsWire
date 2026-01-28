//
//  FeedlyFetchIdsForMissingArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 7/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

final class FeedlyFetchIdsForMissingArticlesOperation: FeedlyOperation, FeedlyEntryIdentifierProviding {

	private let account: Account

	private(set) var entryIDs = Set<String>()

	init(account: Account) {
		self.account = account
	}

	override func run() {
		Task {
			do {
				let articleIDs = try await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()
				entryIDs.formUnion(articleIDs)
				didFinish()
			} catch {
				didFinish(with: error)
			}
		}
	}
}
