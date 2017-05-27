//
//  ArticleStatusProtocol.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum ArticleStatusKey: String {

	case read = "read"
	case starred = "starred"
	case userDeleted = "userDeleted"
}

public protocol ArticleStatus {

	var read: Bool {get set}
	var starred: Bool {get set}
	var userDeleted: Bool {get set}
	var dateArrived: Date {get}

	func boolStatusForKey(_ articleStatusKey: ArticleStatusKey) -> Bool
	func setBoolStatusForKey(_ status: Bool, articleStatusKey: ArticleStatusKey)
}

public extension ArticleStatus {

	func boolStatusForKey(_ articleStatusKey: ArticleStatusKey) -> Bool {

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
