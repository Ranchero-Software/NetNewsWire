//
//  ArticleStatus+Database.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data

extension ArticleStatus {
	
	convenience init?(row: FMResultSet) {
		
		let articleID = row.string(forColumn: DatabaseKey.articleID)
		if (articleID == nil) {
			return nil
		}
		let read = row.bool(forColumn: DatabaseKey.read)
		let starred = row.bool(forColumn: DatabaseKey.starred)
		let userDeleted = row.bool(forColumn: DatabaseKey.userDeleted)
		
		var dateArrived = row.date(forColumn: DatabaseKey.dateArrived)
		if (dateArrived == nil) {
			dateArrived = NSDate.distantPast
		}
		
		let accountInfoPlist = accountInfoWithRow(row)
		
		self.init(articleID: articleID!, read: read, starred: starred, userDeleted: userDeleted, dateArrived: dateArrived!, accountInfo: accountInfoPlist)
	}
	
	func databaseDictionary() -> NSDictionary {
		
		let d = NSMutableDictionary()
		
		d[DatabaseKey.articleID] = articleID
		d[DatabaseKey.read] = read
		d[DatabaseKey.starred] = starred
		d[DatabaseKey.userDeleted] = userDeleted
		d[DatabaseKey.dateArrived] = dateArrived
		
		if let accountInfo = accountInfo, let data = PropertyListTransformer.data(withPropertyList: accountInfo) {
			d[DatabaseKey.accountInfo] = data
		}

		return d.copy() as! NSDictionary
	}
}

