//
//  AccountInfo.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

public typealias AccountInfo = [String: AnyObject]

// AccountInfo is a plist-compatible dictionary that’s stored as a binary plist in the database.

//func accountInfoWithRow(_ row: FMResultSet) -> AccountInfo? {
//	
//	guard let rawAccountInfo = row.data(forColumn: DatabaseKey.accountInfo) else {
//		return nil
//	}
//	return propertyList(withData: rawAccountInfo) as? AccountInfo
//}

