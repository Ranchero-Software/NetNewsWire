//
//  FeedlyFetchIdsForMissingArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 7/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

final class FeedlyFetchIdsForMissingArticlesOperation: FeedlyOperation, FeedlyEntryIdentifierProviding, @unchecked Sendable {

	private let account: Account

	private(set) var entryIds = Set<String>()

	@MainActor init(account: Account) {
		self.account = account
		super.init()
	}

	@MainActor override func run() {
		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { result in
			Task { @MainActor in
				switch result {
				case .success(let articleIds):
					self.entryIds.formUnion(articleIds)
					self.didComplete()

				case .failure(let error):
					self.didComplete(with: error)
				}
			}
		}
	}
}
