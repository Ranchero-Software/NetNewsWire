//
//  ArticleProtocol.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol Article: class {

	var account: Account? {get}
	var feedID: String {get}
	var feed: Feed? {get}
	var articleID: String {get}
	var status: ArticleStatus! {get}

	var guid: String? {get}
	var title: String? {get}
	var body: String? {get}
	var link: String? {get}
	var permalink: String? {get}
	var author: String? {get}

	var datePublished: Date? {get}
	var logicalDatePublished: Date {get} //datePublished or something reasonable.
	var dateModified: Date? {get}
}

public extension Article {

	var feed: Feed? {
		get {
			return account?.existingFeedWithID(feedID)
		}
	}
	
	var logicalDatePublished: Date {
		get {
			if let d = datePublished {
				return d
			}
			if let d = dateModified {
				return d
			}
			return status.dateArrived as Date
		}
	}
}

public func articleArraysAreIdentical(array1: [Article], array2: [Article]) -> Bool {
	
	if array1.count != array2.count {
		return false
	}
	
	var index = 0
	for oneItem in array1 {
		if oneItem !== array2[index] {
			return false
		}
		index = index + 1
	}
	
	return true
}

