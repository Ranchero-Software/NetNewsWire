//
//  FeedListFeed.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSParser
import RSWeb

extension Notification.Name {

	public static let FeedListFeedDidBecomeAvailable = Notification.Name(rawValue: "FeedListFeedDidBecomeAvailable")
}

final class FeedListFeed: Hashable, DisplayNameProvider {

	let name: String
	let url: String
	let homePageURL: String
	var lastDownloadAttemptDate: Date? = nil

	var parsedFeed: ParsedFeed? = nil {
		didSet {
			postFeedListFeedDidBecomeAvailableNotification()
		}
	}

	var nameForDisplay: String { // DisplayNameProvider
		return name
	}

	init(name: String, url: String, homePageURL: String) {

		self.name = name
		self.url = url
		self.homePageURL = homePageURL
	}

	private struct Key {
		static let name = "name"
		static let editedName = "editedName" // Used in DefaultFeeds.plist
		static let url = "url"
		static let homePageURL = "homePageURL"
	}

	convenience init(dictionary: [String: String]) {

		let name = (dictionary[Key.name] ?? dictionary[Key.editedName])!
		let url = dictionary[Key.url]!
		let homePageURL = dictionary[Key.homePageURL]!

		self.init(name: name, url: url, homePageURL: homePageURL)
	}

	func downloadIfNeeded() {

		// Not doing feed previews until after 1.0.

//		guard let lastDownloadAttemptDate = lastDownloadAttemptDate else {
//			downloadFeed()
//			return
//		}
//
//		let cutoffDate = Date().addingTimeInterval(-(30 * 60)) // 30 minutes in the past
//		if lastDownloadAttemptDate < cutoffDate {
//			downloadFeed()
//		}
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(url)
	}

	// MARK: - Equatable

	static func ==(lhs: FeedListFeed, rhs: FeedListFeed) -> Bool {

		return lhs.url == rhs.url && lhs.name == rhs.name && lhs.homePageURL == rhs.homePageURL
	}
}

private extension FeedListFeed {

	func postFeedListFeedDidBecomeAvailableNotification() {

//		NotificationCenter.default.post(name: .FeedListFeedDidBecomeAvailable, object: self, userInfo: nil)
	}

	func downloadFeed() {

//		lastDownloadAttemptDate = Date()
//		guard let feedURL = URL(string: url) else {
//			return
//		}
//
//		downloadUsingCache(feedURL) { (data, response, error) in
//
//			guard let data = data, error == nil else {
//				return
//			}
//
//			let parserData = ParserData(url: self.url, data: data)
//			FeedParser.parse(parserData) { (parsedFeed, error) in
//
//				if let parsedFeed = parsedFeed, parsedFeed.items.count > 0 {
//					self.parsedFeed = parsedFeed
//				}
//			}
//		}
	}
}
