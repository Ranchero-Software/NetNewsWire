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

public final class Feed: DisplayNameProvider, UnreadCountProvider, Hashable {

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

	// MARK: - Disk Dictionary

	private struct Key {
		static let url = "url"
		static let feedID = "feedID"
		static let homePageURL = "homePageURL"
		static let name = "name"
		static let editedName = "editedName"
		static let conditionalGetInfo = "conditionalGetInfo"
		static let contentHash = "contentHash"
		static let unreadCount = "unreadCount"
	}

	convenience public init?(accountID: String, dictionary: [String: Any]) {

		guard let url = dictionary[Key.url] as? String, let feedID = dictionary[Key.feedID] as? String else {
			return nil
		}

		self.init(accountID: accountID, url: url, feedID: feedID)
		self.homePageURL = dictionary[Key.homePageURL] as? String
		self.name = dictionary[Key.name] as? String
		self.editedName = dictionary[Key.editedName] as? String
		self.contentHash = dictionary[Key.contentHash] as? String

		if let conditionalGetInfoDictionary = dictionary[Key.conditionalGetInfo] as? [String: String] {
			self.conditionalGetInfo = HTTPConditionalGetInfo(dictionary: conditionalGetInfoDictionary)
		}

		if let savedUnreadCount = dictionary[Key.unreadCount] as? Int {
			self.unreadCount = savedUnreadCount
		}
	}

	public var dictionary: [String: Any] {
		get {
			var d = [String: Any]()

			d[Key.url] = url
			d[Key.feedID] = feedID
			if let homePageURL = homePageURL {
				d[Key.homePageURL] = homePageURL
			}
			if let name = name {
				d[Key.name] = name
			}
			if let editedName = editedName {
				d[Key.editedName] = editedName
			}
			if let contentHash = contentHash {
				d[Key.contentHash] = contentHash
			}
			if unreadCount > 0 {
				d[Key.unreadCount] = unreadCount
			}
			if let conditionalGetInfo = conditionalGetInfo {
				d[Key.conditionalGetInfo] = conditionalGetInfo.dictionary
			}

			return d
		}
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

