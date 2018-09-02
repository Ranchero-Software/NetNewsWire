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
import Articles

public final class Feed: DisplayNameProvider, UnreadCountProvider, Hashable {

	public let accountID: String
	public let url: String
	public let feedID: String

	private var _homePageURL: String?
	public var homePageURL: String? {
		get {
			return _homePageURL
		}
		set {
			if let url = newValue {
				_homePageURL = url.rs_normalizedURL()
			}
			else {
				_homePageURL = nil
			}
		}
	}

	public var iconURL: String?
	public var faviconURL: String?
	public var name: String?
	public var authors: Set<Author>?

	public var editedName: String? {
		didSet {
			postDisplayNameDidChangeNotification()
		}
	}

	public var conditionalGetInfo: HTTPConditionalGetInfo?
	public var contentHash: String?

	// MARK: - DisplayNameProvider

	public var nameForDisplay: String {
		if let s = editedName, !s.isEmpty {
			return s
		}
		if let s = name, !s.isEmpty {
			return s
		}
		return NSLocalizedString("Untitled", comment: "Feed name")
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
	}

	// MARK: - Disk Dictionary

	private struct Key {
		static let url = "url"
		static let feedID = "feedID"
		static let homePageURL = "homePageURL"
		static let iconURL = "iconURL"
		static let faviconURL = "faviconURL"
		static let name = "name"
		static let editedName = "editedName"
		static let authors = "authors"
		static let conditionalGetInfo = "conditionalGetInfo"
		static let contentHash = "contentHash"
		static let unreadCount = "unreadCount"
	}

	convenience public init?(accountID: String, dictionary: [String: Any]) {

		guard let url = dictionary[Key.url] as? String else {
			return nil
		}
		let feedID = dictionary[Key.feedID] as? String ?? url
		
		self.init(accountID: accountID, url: url, feedID: feedID)
		self.homePageURL = dictionary[Key.homePageURL] as? String
		self.iconURL = dictionary[Key.iconURL] as? String
		self.faviconURL = dictionary[Key.faviconURL] as? String
		self.name = dictionary[Key.name] as? String
		self.editedName = dictionary[Key.editedName] as? String
		self.contentHash = dictionary[Key.contentHash] as? String

		if let conditionalGetInfoDictionary = dictionary[Key.conditionalGetInfo] as? [String: String] {
			self.conditionalGetInfo = HTTPConditionalGetInfo(dictionary: conditionalGetInfoDictionary)
		}

		if let savedUnreadCount = dictionary[Key.unreadCount] as? Int {
			self.unreadCount = savedUnreadCount
		}

		if let authorsDiskArray = dictionary[Key.authors] as? [[String: Any]] {
			self.authors = Author.authorsWithDiskArray(authorsDiskArray)
		}
	}

	public static func isFeedDictionary(_ d: [String: Any]) -> Bool {

		return d[Key.url] != nil
	}

	public var dictionary: [String: Any] {
		var d = [String: Any]()
		
		d[Key.url] = url
		
		// feedID is not repeated when it’s the same as url
		if (feedID != url) {
			d[Key.feedID] = feedID
		}
		
		if let homePageURL = homePageURL {
			d[Key.homePageURL] = homePageURL
		}
		if let iconURL = iconURL {
			d[Key.iconURL] = iconURL
		}
		if let faviconURL = faviconURL {
			d[Key.faviconURL] = faviconURL
		}
		if let name = name {
			d[Key.name] = name
		}
		if let editedName = editedName {
			d[Key.editedName] = editedName
		}
		if let authorsArray = authors?.diskArray() {
			d[Key.authors] = authorsArray
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

	// MARK: - Debug

	public func debugDropConditionalGetInfo() {

		conditionalGetInfo = nil
		contentHash = nil
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(feedID)
	}

	// MARK: - Equatable

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

extension Set where Element == Feed {

	func feedIDs() -> Set<String> {

		return Set<String>(map { $0.feedID })
	}
}
