//
//  Feed+Account.swift
//  Account
//
//  Created by Brent Simmons on 9/17/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data

struct FeedDictionaryKey {
	
	
}

public extension Feed {

	var account: Account? {
		get {
			return accountWithID(accountID)
		}
	}
}
