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

typealias DiskFeedDictionary = [String: Any]

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
	
	static func importFeeds(_ feedDictionaries: [DiskFeedDictionary], account: Account) {
		
		let feedsToImport = feeds(with: feedDictionaries, accountID: account.accountID)
		for feed in feedsToImport {
			if !account.hasFeed(with: feed.feedID) {
				let _ = account.addFeed(feed, to: nil)
			}
		}
	}
	
	private static func feeds(with feedDictionaries: [DiskFeedDictionary], accountID: String) -> Set<Feed> {
		
		let feeds = Set(feedDictionaries.map { Feed(accountID: accountID, dictionary: $0) })
		return feeds
	}
}

