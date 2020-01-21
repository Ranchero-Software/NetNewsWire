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
	private let log: OSLog
	
	private(set) var entryIds = Set<String>()
	
	init(account: Account, log: OSLog) {
		self.account = account
		self.log = log
	}
	
	override func run() {
		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { result in
			switch result {
			case .success(let articleIds):
				self.entryIds.formUnion(articleIds)
				self.didFinish()
				
			case .failure(let error):
				self.didFinish(with: error)
			}
		}
	}
}
