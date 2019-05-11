//
//  DefaultFeedsImporter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/13/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Account
import RSCore

struct DefaultFeedsImporter {
	
	static func importIfNeeded(_ isFirstRun: Bool, account: Account) {
		guard shouldImportDefaultFeeds(isFirstRun) else {
			return
		}

		appDelegate.logDebugMessage("Importing default feeds.")
		let defaultFeedsURL = Bundle.main.url(forResource: "DefaultFeeds", withExtension: "opml")!
		AccountManager.shared.defaultAccount.importOPML(defaultFeedsURL) { result in }
	}

	private static func shouldImportDefaultFeeds(_ isFirstRun: Bool) -> Bool {
		if !isFirstRun || AccountManager.shared.anyAccountHasAtLeastOneFeed() {
			return false
		}
		return true
	}
}

