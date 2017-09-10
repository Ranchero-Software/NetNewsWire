//
//  AccountInfo.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

// This is used by an Account that needs to store extra info.
// It’s stored as a binary plist in the database.

public struct AccountInfo: Equatable {

	var plist: [String: AnyObject]?

	init(plist: [String: AnyObject]) {
		
		self.plist = plist
	}
	
	public static func ==(lhs: AccountInfo, rhs: AccountInfo) -> Bool {

		return true // TODO
	}
}

//func accountInfoWithRow(_ row: FMResultSet) -> AccountInfo? {
//	
//	guard let rawAccountInfo = row.data(forColumn: DatabaseKey.accountInfo) else {
//		return nil
//	}
//	return propertyList(withData: rawAccountInfo) as? AccountInfo
//}

