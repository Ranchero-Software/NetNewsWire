//
//  AccountInfo.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

public struct AccountInfo: Equatable {

	var dictionary: [String: AnyObject]?

	public static func ==(lhs: AccountInfo, rhs: AccountInfo) -> Bool {

		return true // TODO
	}
}

// AccountInfo is a plist-compatible dictionary that’s stored as a binary plist in the database.

//func accountInfoWithRow(_ row: FMResultSet) -> AccountInfo? {
//	
//	guard let rawAccountInfo = row.data(forColumn: DatabaseKey.accountInfo) else {
//		return nil
//	}
//	return propertyList(withData: rawAccountInfo) as? AccountInfo
//}

