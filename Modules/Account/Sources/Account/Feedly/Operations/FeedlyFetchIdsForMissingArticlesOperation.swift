//
//  FeedlyFetchIDsForMissingArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 7/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

final class FeedlyFetchIDsForMissingArticlesOperation: FeedlyOperation, FeedlyEntryIdentifierProviding, @unchecked Sendable {

	private let account: Account

	private(set) var entryIDs = Set<String>()

	@MainActor init(account: Account) {
		self.account = account
		super.init()
	}

	@MainActor override func run() {
		Task { @MainActor in
			do {
				let articleIDs = try await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()
				entryIDs.formUnion(articleIDs)
				didComplete()
			} catch {
				didComplete(with: error)
			}
		}
	}
}
