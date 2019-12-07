//
//  WebFeed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb
import Articles

public final class WebFeed: Feed, Renamable, Hashable {

	public var defaultReadFilterType: ReadFilterType {
		return .none
	}

	public var feedID: FeedIdentifier? {
		guard let accountID = account?.accountID else {
			assertionFailure("Expected feed.account, but got nil.")
			return nil
		}
		return FeedIdentifier.webFeed(accountID, webFeedID)
	}

	public weak var account: Account?
	public let url: String

	public var webFeedID: String {
		get {
			return metadata.webFeedID
		}
		set {
			metadata.webFeedID = newValue
		}
	}

	public var homePageURL: String? {
		get {
			return metadata.homePageURL
		}
		set {
			if let url = newValue {
				metadata.homePageURL = url.rs_normalizedURL()
			}
			else {
				metadata.homePageURL = nil
			}
		}
	}

	// Note: this is available only if the icon URL was available in the feed.
	// The icon URL is a JSON-Feed-only feature.
	// Otherwise we find an icon URL via other means, but we don’t store it
	// as part of feed metadata.
	public var iconURL: String? {
		get {
			return metadata.iconURL
		}
		set {
			metadata.iconURL = newValue
		}
	}

	// Note: this is available only if the favicon URL was available in the feed.
	// The favicon URL is a JSON-Feed-only feature.
	// Otherwise we find a favicon URL via other means, but we don’t store it
	// as part of feed metadata.
	public var faviconURL: String? {
		get {
			return metadata.faviconURL
		}
		set {
			metadata.faviconURL = newValue
		}
	}

	public var name: String?

	public var authors: Set<Author>? {
		get {
			if let authorsArray = metadata.authors {
				return Set(authorsArray)
			}
			return nil
		}
		set {
			if let authorsSet = newValue {
				metadata.authors = Array(authorsSet)
			}
			else {
				metadata.authors = nil
			}
		}
	}

	public var editedName: String? {
		// Don’t let editedName == ""
		get {
			guard let s = metadata.editedName, !s.isEmpty else {
				return nil
			}
			return s
		}
		set {
			if newValue != editedName {
				if let valueToSet = newValue, !valueToSet.isEmpty {
					metadata.editedName = valueToSet
				}
				else {
					metadata.editedName = nil
				}
				postDisplayNameDidChangeNotification()
			}
		}
	}

	public var conditionalGetInfo: HTTPConditionalGetInfo? {
		get {
			return metadata.conditionalGetInfo
		}
		set {
			metadata.conditionalGetInfo = newValue
		}
	}

	public var contentHash: String? {
		get {
			return metadata.contentHash
		}
		set {
			metadata.contentHash = newValue
		}
	}

	public var isNotifyAboutNewArticles: Bool? {
		get {
			return metadata.isNotifyAboutNewArticles
		}
		set {
			metadata.isNotifyAboutNewArticles = newValue
		}
	}
	
	public var isArticleExtractorAlwaysOn: Bool? {
		get {
			return metadata.isArticleExtractorAlwaysOn
		}
		set {
			metadata.isArticleExtractorAlwaysOn = newValue
		}
	}
	
	public var subscriptionID: String? {
		get {
			return metadata.subscriptionID
		}
		set {
			metadata.subscriptionID = newValue
		}
	}

	// Folder Name: Sync Service Relationship ID
	public var folderRelationship: [String: String]? {
		get {
			return metadata.folderRelationship
		}
		set {
			metadata.folderRelationship = newValue
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

	public func rename(to newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let account = account else { return }
		account.renameWebFeed(self, to: newName, completion: completion)
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

	var metadata: WebFeedMetadata

	// MARK: - Private

	private let accountID: String // Used for hashing and equality; account may turn nil

	// MARK: - Init

	init(account: Account, url: String, metadata: WebFeedMetadata) {
		self.account = account
		self.accountID = account.accountID
		self.url = url
		self.metadata = metadata
	}

	// MARK: - Debug

	public func debugDropConditionalGetInfo() {
		conditionalGetInfo = nil
		contentHash = nil
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(webFeedID)
	}

	// MARK: - Equatable

	public class func ==(lhs: WebFeed, rhs: WebFeed) -> Bool {
		return lhs.webFeedID == rhs.webFeedID && lhs.accountID == rhs.accountID
	}
}

// MARK: - OPMLRepresentable

extension WebFeed: OPMLRepresentable {

	public func OPMLString(indentLevel: Int, strictConformance: Bool) -> String {
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

extension Set where Element == WebFeed {

	func webFeedIDs() -> Set<String> {
		return Set<String>(map { $0.webFeedID })
	}
}
