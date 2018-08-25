//
//  FeedListFolder.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Articles

final class FeedListFolder: Hashable, DisplayNameProvider {

	let name: String
	let feeds: Set<FeedListFeed>

	var nameForDisplay: String { // DisplayNameProvider
		return name
	}

	init(name: String, feeds: Set<FeedListFeed>) {
		self.name = name
		self.feeds = feeds
	}
}
