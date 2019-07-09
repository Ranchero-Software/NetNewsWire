//
//  ArticleStatus+Database.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Articles

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

	public func databaseDictionary() -> DatabaseDictionary? {
		return [DatabaseKey.articleID: articleID, DatabaseKey.read: read, DatabaseKey.starred: starred, DatabaseKey.userDeleted: userDeleted, DatabaseKey.dateArrived: dateArrived]
	}
}

