//
//  ArticleStatus.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum ArticleStatusKey: String {
	
	case read = "read"
	case starred = "starred"
	case userDeleted = "userDeleted"
}

public struct ArticleStatus: Hashable {
	
	public let articleID: String
	public let dateArrived: Date
	public let hashValue: Int

	public var read = false
	public var starred = false
	public var userDeleted = false
	public var accountInfo: AccountInfo?
	
	public init(articleID: String, read: Bool, starred: Bool, userDeleted: Bool, dateArrived: Date, accountInfo: AccountInfo?) {
		
		self.articleID = articleID
		self.read = read
		self.starred = starred
		self.userDeleted = userDeleted
		self.dateArrived = dateArrived
		self.accountInfo = accountInfo
		self.hashValue = articleID.hashValue
	}

	public init(articleID: String, dateArrived: Date) {

		self.init(articleID: articleID, read: false, starred: false, userDeleted: false, dateArrived: dateArrived, accountInfo: nil)
	}

	public func boolStatus(forKey key: String) -> Bool {
		
		if let articleStatusKey = ArticleStatusKey(rawValue: key) {
			switch articleStatusKey {
			case .read:
				return read
			case .starred:
				return starred
			case .userDeleted:
				return userDeleted
			}
		}
		else if let flag = accountInfo?[key] as? Bool {
			return flag
		}
		return false
	}
	
	public mutating func setBoolStatus(_ status: Bool, forKey key: String) {

		if let articleStatusKey = ArticleStatusKey(rawValue: key) {
			switch articleStatusKey {
			case .read:
				read = status
			case .starred:
				starred = status
			case .userDeleted:
				userDeleted = status
			}
		}
//		else {
//			if accountInfo == nil {
//				accountInfo = AccountInfo()
//			}
//			accountInfo![key] = status
//		}
	}

	public static func ==(lhs: ArticleStatus, rhs: ArticleStatus) -> Bool {
		
		return lhs.hashValue == rhs.hashValue && lhs.articleID == rhs.articleID && lhs.dateArrived == rhs.dateArrived && lhs.read == rhs.read && lhs.starred == rhs.starred && lhs.userDeleted == rhs.userDeleted && lhs.accountInfo == rhs.accountInfo
	}
}
