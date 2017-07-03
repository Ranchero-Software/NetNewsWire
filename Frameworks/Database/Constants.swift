//
//  Keys.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

public struct DatabaseTableName {
	
	static let articles = "articles"
	static let statuses = "statuses"
}

public struct DatabaseKey {
	
	static let articleID = "articleID"
	static let accountInfo = "accountInfo"
	
	// ArticleStatus
	static let read = "read"
	static let starred = "starred"
	static let userDeleted = "userDeleted"
	static let dateArrived = "dateArrived"
}

