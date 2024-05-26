//
//  Feed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
import Articles
import Core

@MainActor public final class Feed: Renamable, DisplayNameProvider, UnreadCountProvider, Hashable {

	public weak var account: Account?
	public let url: String
	public let feedID: String

	public var homePageURL: String? {
		get {
			return metadata.homePageURL
		}
		set {
			if let url = newValue, !url.isEmpty {
				metadata.homePageURL = url.normalizedURL
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

	public var name: String? {
		didSet {
			if name != oldValue {
				postDisplayNameDidChangeNotification()
			}
		}
	}

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

	public var shouldSendUserNotificationForNewArticles: Bool? {
		get {
			return metadata.shouldSendUserNotificationForNewArticles
		}
		set {
			metadata.shouldSendUserNotificationForNewArticles = newValue
		}
	}
	
	public var isArticleExtractorAlwaysOn: Bool? {
		get {
            metadata.isArticleExtractorAlwaysOn
		}
		set {
			metadata.isArticleExtractorAlwaysOn = newValue
		}
	}
	
	public var sinceToken: String? {
		get {
			return metadata.sinceToken
		}
		set {
			metadata.sinceToken = newValue
		}
	}

	public var externalID: String? {
		get {
			return metadata.externalID
		}
		set {
			metadata.externalID = newValue
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

	public func rename(to newName: String) async throws {
		
		guard let account else {
			return
		}

		try await account.renameFeed(self, to: newName)
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
    
    // MARK: - NotificationDisplayName
    public var notificationDisplayName: String {
        #if os(macOS)
        if self.url.contains("www.reddit.com") {
            return NSLocalizedString("Show notifications for new posts", comment: "notifyNameDisplay / Reddit")
        } else {
            return NSLocalizedString("Show notifications for new articles", comment: "notifyNameDisplay / Default")
        }
        #else
        if self.url.contains("www.reddit.com") {
            return NSLocalizedString("Notify about new posts", comment: "notifyNameDisplay / Reddit")
        } else {
            return NSLocalizedString("Notify about new articles", comment: "notifyNameDisplay / Default")
        }
        #endif
    }

	var metadata: FeedMetadata

	// MARK: - Private

	private let accountID: String // Used for hashing and equality; account may turn nil

	// MARK: - Init

	init(account: Account, url: String, metadata: FeedMetadata) {
		self.account = account
		self.accountID = account.accountID
		self.url = url
		self.feedID = metadata.feedID
		self.metadata = metadata
	}

	// MARK: - API
	
	public func dropConditionalGetInfo() {
		conditionalGetInfo = nil
		contentHash = nil
		sinceToken = nil
	}

	// MARK: - Hashable

	nonisolated public func hash(into hasher: inout Hasher) {
		hasher.combine(feedID)
	}

	// MARK: - Equatable

	nonisolated public class func ==(lhs: Feed, rhs: Feed) -> Bool {
		return lhs.feedID == rhs.feedID && lhs.accountID == rhs.accountID
	}
}

// MARK: - OPMLRepresentable

extension Feed: OPMLRepresentable {

	public func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String {
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
		let escapedName = nameToUse!.escapingSpecialXMLCharacters
		
		var escapedHomePageURL = ""
		if let homePageURL = homePageURL {
			escapedHomePageURL = homePageURL.escapingSpecialXMLCharacters
		}
		let escapedFeedURL = url.escapingSpecialXMLCharacters

		var s = "<outline text=\"\(escapedName)\" title=\"\(escapedName)\" description=\"\" type=\"rss\" version=\"RSS\" htmlUrl=\"\(escapedHomePageURL)\" xmlUrl=\"\(escapedFeedURL)\"/>\n"
		s = s.prepending(tabCount: indentLevel)

		return s
	}
}

extension Set where Element == Feed {

	@MainActor func feedIDs() -> Set<String> {
		return Set<String>(map { $0.feedID })
	}
	
	@MainActor func sorted() -> Array<Feed> {
		return sorted(by: { (feed1, feed2) -> Bool in
			if feed1.nameForDisplay.localizedStandardCompare(feed2.nameForDisplay) == .orderedSame {
				return feed1.url < feed2.url
			}
			return feed1.nameForDisplay.localizedStandardCompare(feed2.nameForDisplay) == .orderedAscending
		})
	}
	
}
