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

private func shouldImportDefaultFeeds(_ isFirstRun: Bool) -> Bool {
	
	if !isFirstRun {
		return false
	}

	for oneAccount in AccountManager.sharedInstance.accounts {
		if oneAccount.hasAtLeastOneFeed {
			return false
		}
	}
	return true
}

private func defaultFeedsArray() -> NSArray {
	
	let f = Bundle.main.path(forResource: "DefaultFeeds", ofType: "plist")!
	return NSArray(contentsOfFile: f)!
}

private func importFeedsWithArray(_ defaultFeeds: NSArray, _ account: Account) {

	for d in defaultFeeds {

		guard let oneFeedDictionary = d as? NSDictionary else {
			continue
		}

		let oneFeed = LocalFeed(account: account, diskDictionary: oneFeedDictionary)!
		let _ = account.addItem(oneFeed)
	}
}

func importDefaultFeedsIfNeeded(_ isFirstRun: Bool, account: Account) {
	
	if !shouldImportDefaultFeeds(isFirstRun) {
		return
	}

	importFeedsWithArray(defaultFeedsArray(), account)
}
