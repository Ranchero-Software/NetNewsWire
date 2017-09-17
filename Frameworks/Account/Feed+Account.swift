//
//  Feed+Account.swift
//  Account
//
//  Created by Brent Simmons on 9/17/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data

public extension Feed {

	var account: Account? {
		get {
			return Account.existingAccountWithID(accountID)
		}
	}
}
