//
//  Feed.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb

public final class Feed: DisplayNameProvider, UnreadCountProvider, Codable, Hashable {

	public let accountID: String
	public let url: String
	public let feedID: String
	public var homePageURL: String?
	public var name: String?
	public var editedName: String?
	public var conditionalGetInfo: HTTPConditionalGetInfo?
	public var contentHash: String?
	public let hashValue: Int

	// MARK: - DisplayNameProvider

	public var nameForDisplay: String {
		get {
			return (editedName ?? name) ?? NSLocalizedString("Untitled", comment: "Feed name")
		}
	}

	// MARK: - UnreadCountProvider
	
	public var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	// MARK: - Init

	public init(accountID: String, url: String, feedID: String) {

		self.accountID = accountID
		self.url = url
		self.feedID = feedID
		self.hashValue = accountID.hashValue ^ url.hashValue ^ feedID.hashValue
	}

	public class func ==(lhs: Feed, rhs: Feed) -> Bool {

		return lhs === rhs
	}
}

// MARK: - OPMLRepresentable

extension Feed: OPMLRepresentable {

	public func OPMLString(indentLevel: Int) -> String {

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

