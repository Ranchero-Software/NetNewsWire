//
//  FeedlyFetchIDsForMissingArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 7/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

final class FeedlyFetchIDsForMissingArticlesOperation: FeedlyOperation, FeedlyEntryIdentifierProviding, Logging {

	private let account: Account
	
	private(set) var entryIDs = Set<String>()
	
	init(account: Account) {
		self.account = account
	}
	
	override func run() {
		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { result in
			switch result {
			case .success(let articleIds):
				self.entryIDs.formUnion(articleIds)
				self.didFinish()
				
			case .failure(let error):
                self.logger.error("Failed to fetch articleIDs: \(error.localizedDescription, privacy: .public).")
				self.didFinish(with: error)
			}
		}
	}
}
