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
	
	static func importDefaultFeeds(account: Account) {
		let defaultFeedsURL = Bundle.main.url(forResource: "DefaultFeeds", withExtension: "opml")!
		AccountManager.shared.defaultAccount.importOPML(defaultFeedsURL) { result in }
	}
	
}

