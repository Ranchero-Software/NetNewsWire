//
//  FeedListFolder.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

final class FeedListFolder: Hashable {

	let name: String
	let feeds: Set<FeedListFeed>
	let hashValue: Int

	init(name: String, feeds: Set<FeedListFeed>) {

		self.name = name
		self.feeds = feeds
		self.hashValue = name.hashValue
	}

	static func ==(lhs: FeedListFolder, rhs: FeedListFolder) -> Bool {

		return lhs === rhs
	}
}
