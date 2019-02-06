//
//  DefaultFeedsImporter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/13/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import Account
import RSCore

typealias DiskFeedDictionary = [String: Any]

struct DefaultFeedsImporter {
	
	static func importIfNeeded(_ firstRun: Bool, account: Account) {
		
		if shouldImportDefaultFeeds(firstRun) {
			appDelegate.logDebugMessage("Importing default feeds.")
			FeedsImporter.importFeeds(defaultFeeds(), account: account)
		}
	}
	
	private static func defaultFeeds() -> [DiskFeedDictionary] {
		
		let f = Bundle.main.path(forResource: "DefaultFeeds", ofType: "plist")!
		return NSArray(contentsOfFile: f)! as! [DiskFeedDictionary]
	}
	
	private static func shouldImportDefaultFeeds(_ isFirstRun: Bool) -> Bool {
		
		if !isFirstRun || AccountManager.shared.anyAccountHasAtLeastOneFeed() {
			return false
		}
		return true
	}
}

struct FeedsImporter {
	
	static func importFeeds(_ feedDictionaries: [DiskFeedDictionary], account: Account) {
		
		let feedsToImport = feeds(with: feedDictionaries, account: account)
		
		BatchUpdate.shared.perform {
			feedsToImport.forEach{ account.addFeed($0) }
		}
		account.structureDidChange()
	}
	
	private static func feeds(with feedDictionaries: [DiskFeedDictionary], account: Account) -> Set<Feed> {

		let feedArray = feedDictionaries.compactMap { Feed(account: account, dictionary: $0) }
		return Set(feedArray)
	}
}

