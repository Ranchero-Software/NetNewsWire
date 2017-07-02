//
//  Feed.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

public final class Feed: UnreadCountProvider, DisplayNameProvider, Hashable {

	public let account: Account
	public let url: String
	public let feedID: String

	public var homePageURL: String?
	public var name: String?
	public var editedName: String?
	public var nameForDisplay: String {
		get {
			return (editedName ?? name) ?? NSLocalizedString("Untitled", comment: "Feed name")
		}
	}

	public var articles = Set<Article>()
	public var accountInfo: [String: Any]? //If account needs to store more data

	public init(account: Account, url: String, feedID: String) {

		self.account = account
		self.url = url
		self.feedID = feedID
		self.hashValue = account.hashValue + url.hashValue + feedID.hashValue
	}

	public fetchArticles() -> Set<Article> {

		articles = account.fetchArticles(self)
		return articles
	}

	public class func ==(lhs: Feed, rhs: Feed) -> Bool {

		return lhs === rhs
	}
}

public extension Feed: OPMLRepresentable {

	func OPMLString(indentLevel: Int) -> String {

		let escapedName = nameForDisplay.rs_stringByEscapingSpecialXMLCharacters()
		var escapedHomePageURL = ""
		if let homePageURL = homePageURL {
			escapedHomePageURL = homePageURL.rs_stringByEscapingSpecialXMLCharacters()
		}
		let escapedFeedURL = url.rs_stringByEscapingSpecialXMLCharacters()

		var s = "<outline text=\"\(escapedName)\" title=\"\(escapedName)\" description=\"\" type=\"rss\" version=\"RSS\" htmlUrl=\"\(escapedHomePageURL)\" xmlUrl=\"\(escapedFeedURL)\"/>\n"
		s = s.rs_string(byPrependingNumberOfTabs: indentLevel)

		return s
	}
}
