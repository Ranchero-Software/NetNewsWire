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

		Task { @MainActor in

			do {
				if let articleIDs = try await account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate() {
					self.entryIDs.formUnion(articleIDs)
				}
				
				self.didFinish()

			} catch {
				self.didFinish(with: error)
			}
		}
	}
}
