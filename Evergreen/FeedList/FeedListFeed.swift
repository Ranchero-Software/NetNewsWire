//
//  FeedListFeed.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

struct FeedListFeed: Hashable, DisplayNameProvider {

	let name: String
	let url: String
	let homePageURL: String
	let hashValue: Int

	var nameForDisplay: String { // DisplayNameProvider
		get {
			return name
		}
	}

	init(name: String, url: String, homePageURL: String) {

		self.name = name
		self.url = url
		self.homePageURL = homePageURL
		self.hashValue = url.hashValue
	}

	private struct Key {
		static let name = "name"
		static let editedName = "editedName" // Used in DefaultFeeds.plist
		static let url = "url"
		static let homePageURL = "homePageURL"
	}

	init(dictionary: [String: String]) {

		let name = (dictionary[Key.name] ?? dictionary[Key.editedName])!
		let url = dictionary[Key.url]!
		let homePageURL = dictionary[Key.homePageURL]!

		self.init(name: name, url: url, homePageURL: homePageURL)
	}

	static func ==(lhs: FeedListFeed, rhs: FeedListFeed) -> Bool {

		return lhs.hashValue == rhs.hashValue && lhs.url == rhs.url && lhs.name == rhs.name && lhs.homePageURL == rhs.homePageURL
	}
}
