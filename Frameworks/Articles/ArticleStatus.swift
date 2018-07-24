//
//  ArticleStatus.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Threading rules:
// * Main-thread only
// * Except: may be created on background thread by StatusesTable.
// Which is safe, because at creation time it’t not yet shared,
// and it won’t be mutated ever on a background thread.

public final class ArticleStatus: Hashable {
	
	public enum Key: String {
		case read = "read"
		case starred = "starred"
		case userDeleted = "userDeleted"
	}
	
	public let articleID: String
	public let dateArrived: Date
	public let hashValue: Int

	public var read = false
	public var starred = false
	public var userDeleted = false
	
	public init(articleID: String, read: Bool, starred: Bool, userDeleted: Bool, dateArrived: Date) {
		
		self.articleID = articleID
		self.read = read
		self.starred = starred
		self.userDeleted = userDeleted
		self.dateArrived = dateArrived
		self.hashValue = articleID.hashValue
	}

	public convenience init(articleID: String, dateArrived: Date) {

		self.init(articleID: articleID, read: false, starred: false, userDeleted: false, dateArrived: dateArrived)
	}

	public func boolStatus(forKey key: ArticleStatus.Key) -> Bool {
		
		switch key {
		case .read:
			return read
		case .starred:
			return starred
		case .userDeleted:
			return userDeleted
		}
	}
	
	public func setBoolStatus(_ status: Bool, forKey key: ArticleStatus.Key) {

		switch key {
		case .read:
			read = status
		case .starred:
			starred = status
		case .userDeleted:
			userDeleted = status
		}
	}

	public static func ==(lhs: ArticleStatus, rhs: ArticleStatus) -> Bool {
		
		return lhs.hashValue == rhs.hashValue && lhs.articleID == rhs.articleID && lhs.dateArrived == rhs.dateArrived && lhs.read == rhs.read && lhs.starred == rhs.starred && lhs.userDeleted == rhs.userDeleted
	}
}

public extension Set where Element == ArticleStatus {
	
	public func articleIDs() -> Set<String> {
		
		return Set<String>(map { $0.articleID })
	}
}

public extension Array where Element == ArticleStatus {
	
	public func articleIDs() -> [String] {
		
		return map { $0.articleID }
	}
}
