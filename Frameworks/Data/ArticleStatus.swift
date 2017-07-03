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

public final class ArticleStatus {
	
	public var read = false
	public var starred = false
	public var userDeleted = false
	public var dateArrived: Date
	var accountInfo: AccountInfo?
	
	init(read: Bool, starred: Bool, userDeleted: Bool, dateArrived: Date, accountInfo: AccountInfo?) {
		
		self.read = read
		self.starred = starred
		self.userDeleted = userDeleted
		self.dateArrived = dateArrived
		self.accountInfo = accountInfo
	}
	
	func boolStatusForKey(_ key: String) -> Bool {
		
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
	
	func setBoolStatusForKey(_ status: Bool, key: String) {
		
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
		else {
			if accountInfo == nil {
				accountInfo = AccountInfo()
			}
			accountInfo![key] = status
		}
	}
}
