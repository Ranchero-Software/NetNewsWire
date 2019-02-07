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
import RSDatabase

public final class Feed: DisplayNameProvider, Renamable, UnreadCountProvider, Hashable {

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
		static let conditionalGetLastModified = "lastModified"
		static let conditionalGetEtag = "etag"
		static let contentHash = "contentHash"
	}

	public weak var account: Account?
	public let url: String
	public let feedID: String

	public var homePageURL: String? {
		get {
			return settingsTable.string(for: Key.homePageURL)
		}
		set {
			if let url = newValue {
				settingsTable.setString(url.rs_normalizedURL(), for: Key.homePageURL)
			}
			else {
				settingsTable.setString(nil, for: Key.homePageURL)
			}
		}
	}

	public var iconURL: String? {
		get {
			return settingsTable.string(for: Key.iconURL)
		}
		set {
			settingsTable.setString(newValue, for: Key.iconURL)
		}
	}

	public var faviconURL: String? {
		get {
			return settingsTable.string(for: Key.faviconURL)
		}
		set {
			settingsTable.setString(newValue, for: Key.faviconURL)
		}
	}

	public var name: String? {
		get {
			return settingsTable.string(for: Key.name)
		}
		set {
			let oldNameForDisplay = nameForDisplay
			settingsTable.setString(newValue, for: Key.name)
			if oldNameForDisplay != nameForDisplay {
				postDisplayNameDidChangeNotification()
			}
		}
	}

	public var authors: Set<Author>? {
		get {
			guard let authorsJSON = settingsTable.string(for: Key.authors) else {
				return nil
			}
			return Author.authorsWithJSON(authorsJSON)
		}
		set {
			if let authorsJSON = newValue?.json() {
				settingsTable.setString(authorsJSON, for: Key.authors)
			}
			else {
				settingsTable.setString(nil, for: Key.authors)
			}
		}
	}

	public var editedName: String? {
		// Don’t let editedName == ""
		get {
			guard let s = settingsTable.string(for: Key.editedName), !s.isEmpty else {
				return nil
			}
			return s
		}
		set {
			if newValue != editedName {
				if let valueToSet = newValue, !valueToSet.isEmpty {
					settingsTable.setString(valueToSet, for: Key.editedName)
				}
				else {
					settingsTable.setString(nil, for: Key.editedName)
				}
				postDisplayNameDidChangeNotification()
			}
		}
	}

	public var conditionalGetInfo: HTTPConditionalGetInfo? {
		get {
			let lastModified = settingsTable.string(for: Key.conditionalGetLastModified)
			let etag = settingsTable.string(for: Key.conditionalGetEtag)
			return HTTPConditionalGetInfo(lastModified: lastModified, etag: etag)
		}
		set {
			settingsTable.setString(newValue?.lastModified, for: Key.conditionalGetLastModified)
			settingsTable.setString(newValue?.etag, for: Key.conditionalGetEtag)
		}
	}

	public var contentHash: String? {
		get {
			return settingsTable.string(for: Key.contentHash)
		}
		set {
			settingsTable.setString(newValue, for: Key.contentHash)
		}
	}

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

	// MARK: - Renamable

	public func rename(to newName: String) {
		editedName = newName
	}

	// MARK: - UnreadCountProvider
	
	public var unreadCount: Int {
		get {
			return account?.unreadCount(for: self) ?? 0
		}
		set {
			if unreadCount == newValue {
				return
			}
			account?.setUnreadCount(newValue, for: self)
			postUnreadCountDidChangeNotification()
		}
	}

	private let settingsTable: ODBRawValueTable
	private let accountID: String // Used for hashing and equality; account may turn nil

	// MARK: - Init

	public init(account: Account, url: String, feedID: String) {

		self.account = account
		self.accountID = account.accountID
		self.url = url
		self.feedID = feedID
		self.settingsTable = account.settingsTableForFeed(feedID: feedID)!
	}

	// MARK: - Disk Dictionary

	convenience public init?(account: Account, dictionary: [String: Any]) {

		guard let url = dictionary[Key.url] as? String else {
			return nil
		}
		let feedID = dictionary[Key.feedID] as? String ?? url
		
		self.init(account: account, url: url, feedID: feedID)
		self.editedName = dictionary[Key.editedName] as? String
		self.name = dictionary[Key.name] as? String
	}

	public static func isFeedDictionary(_ d: [String: Any]) -> Bool {

		return d[Key.url] != nil
	}

	// MARK: - Debug

	public func debugDropConditionalGetInfo() {

		conditionalGetInfo = nil
		contentHash = nil
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(feedID)
		hasher.combine(accountID)
	}

	// MARK: - Equatable

	public class func ==(lhs: Feed, rhs: Feed) -> Bool {

		return lhs.feedID == rhs.feedID && lhs.accountID == rhs.accountID
	}
}

// MARK: - OPMLRepresentable

extension Feed: OPMLRepresentable {

	public func OPMLString(indentLevel: Int) -> String {
		// https://github.com/brentsimmons/NetNewsWire/issues/527
		// Don’t use nameForDisplay because that can result in a feed name "Untitled" written to disk,
		// which NetNewsWire may take later to be the actual name.
		var nameToUse = editedName
		if nameToUse == nil {
			nameToUse = name
		}
		if nameToUse == nil {
			nameToUse = ""
		}
		let escapedName = nameToUse!.rs_stringByEscapingSpecialXMLCharacters()
		
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
