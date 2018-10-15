//
//  FeedbinArticleIDArray.swift
//  Account
//
//  Created by Brent Simmons on 10/14/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinArticleIDArray {

	// https://github.com/feedbin/feedbin-api/blob/master/content/unread-entries.md
	//
	// [4087,4088,4089,4090,4091,4092,4093,4094,4095,4096,4097]

	let articleIDs: [Int]

	init(jsonArray: [Any]) {
		self.articleIDs = jsonArray.compactMap { $0 as? Int }
	}
}
