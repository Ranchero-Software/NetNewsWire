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
	
	convenience init(articleID: String, dateArrived: Date, row: FMResultSet) {
		
		let read = row.bool(forColumn: DatabaseKey.read)
		let starred = row.bool(forColumn: DatabaseKey.starred)
		let userDeleted = row.bool(forColumn: DatabaseKey.userDeleted)
		
		self.init(articleID: articleID, read: read, starred: starred, userDeleted: userDeleted, dateArrived: dateArrived)
	}
	
}

extension ArticleStatus: DatabaseObject {
	
	public var databaseID: String {
		return articleID
	}

	public func databaseDictionary() -> NSDictionary? {

		let d = NSMutableDictionary()

		d[DatabaseKey.articleID] = articleID
		d[DatabaseKey.read] = read
		d[DatabaseKey.starred] = starred
		d[DatabaseKey.userDeleted] = userDeleted
		d[DatabaseKey.dateArrived] = dateArrived

		return (d.copy() as! NSDictionary)
	}
}

