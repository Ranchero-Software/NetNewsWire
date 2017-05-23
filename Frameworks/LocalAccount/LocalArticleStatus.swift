//
//  LocalArticleStatus.swift
//  Rainier
//
//  Created by Brent Simmons on 4/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSDatabase
import DataModel

public final class LocalArticleStatus: ArticleStatus, Hashable {

	public var read = false
	public var starred = false
	public var userDeleted = false
	public let dateArrived: Date
	public let hashValue: Int
	let articleID: String

	public init(articleID: String, read: Bool, starred: Bool, userDeleted: Bool, dateArrived: Date) {

		self.articleID = articleID
		self.hashValue = articleID.hashValue
		self.read = read
		self.starred = starred
		self.userDeleted = userDeleted
		self.dateArrived = dateArrived
	}

	// MARK: ArticleStatus

	public func setBoolStatusForKey(_ status: Bool, articleStatusKey: ArticleStatusKey) {

		switch articleStatusKey {

		case .read:
			read = status
		case .starred:
			starred = status
		case .userDeleted:
			userDeleted = status
		}
	}
	
	public func boolStatusForKey(_ articleStatusKey: ArticleStatusKey) -> Bool {
		
		switch articleStatusKey {
			
		case .read:
			return read
		case .starred:
			return starred
		case .userDeleted:
			return userDeleted
		}
	}
}

public func ==(lhs: LocalArticleStatus, rhs: LocalArticleStatus) -> Bool {

	if lhs === rhs {
		return true
	}

	return lhs.hashValue == rhs.hashValue && lhs.articleID == rhs.articleID && lhs.read == rhs.read && lhs.starred == rhs.starred && lhs.userDeleted == rhs.userDeleted && lhs.dateArrived == rhs.dateArrived
}


// LocalDatabase use.

// Database columns.

private let articleStatusIDKey = "articleID"
private let articleStatusReadKey = "read"
private let articleStatusStarredKey = "starred"
private let articleStatusUserDeletedKey = "userDeleted"
private let articleStatusDateArrivedKey = "dateArrived"

extension LocalArticleStatus {

	convenience init?(row: FMResultSet) {
		
		let articleID = row.string(forColumn: articleStatusIDKey)
		if (articleID == nil) {
			return nil
		}
		let read = row.bool(forColumn: articleStatusReadKey)
		let starred = row.bool(forColumn: articleStatusStarredKey)
		let userDeleted = row.bool(forColumn: articleStatusUserDeletedKey)
		
		var dateArrived = row.date(forColumn: articleStatusDateArrivedKey)
		if (dateArrived == nil) {
			dateArrived = NSDate.distantPast
		}
		
		self.init(articleID: articleID!, read: read, starred: starred, userDeleted: userDeleted, dateArrived: dateArrived!)
	}
	
	var databaseDictionary: NSDictionary {
		get {
			return createDatabaseDictionary()
		}
	}

	private func createDatabaseDictionary() -> NSDictionary {

		let d = NSMutableDictionary()

		d[articleIDKey] = articleID
		d[articleStatusReadKey] = read
		d[articleStatusStarredKey] = starred
		d[articleStatusUserDeletedKey] = userDeleted
		d[articleStatusDateArrivedKey] = dateArrived

		return d.copy() as! NSDictionary
	}
}
