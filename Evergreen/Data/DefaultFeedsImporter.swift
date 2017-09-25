//
//  DefaultFeedsImporter.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/13/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data
import Account

typealias DiskFeedDictionary = [String: String]

struct DefaultFeedsImporter {
	
	static func importIfNeeded(_ firstRun: Bool, account: Account) {
		
		if shouldImportDefaultFeeds(firstRun) {
			FeedsImporter.importFeeds(defaultFeeds(), account: account)
		}
	}
	
	private static func defaultFeeds() -> [DiskFeedDictionary] {
		
		let f = Bundle.main.path(forResource: "DefaultFeeds", ofType: "plist")!
		return NSArray(contentsOfFile: f)! as! [DiskFeedDictionary]
	}
	
	private static func shouldImportDefaultFeeds(_ isFirstRun: Bool) -> Bool {
		
		if !isFirstRun {
			return false
		}
		
		for oneAccount in AccountManager.shared.accounts {
			if oneAccount.hasAtLeastOneFeed() {
				return false
			}
		}
		return true
	}
}

struct FeedsImporter {
	
	func importFeeds(_ feedDictionaries: [DiskFeedDictionary], account: Account) {
		
		let feedsToImport = feeds(with: feedDictionaries)
		feedsToImport.forEach(account.addItem)
	}
	
	private func feeds(with feedDictionaries: [DiskFeedDictionary]) -> Set<Feed> {
		
		let feeds = Set(feedDictionaries.map { Feed(account: account, diskFeedDictionary: $0) })
		return feeds
	}
}

private extension Feed {
	
	init?(account: Account, diskFeedDictionary: DiskFeedDictionary) {
		
		
	}
}

