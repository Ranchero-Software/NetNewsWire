//
//  Feed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb
import Articles

@MainActor public final class Feed: SidebarItem, Renamable, Hashable {
	nonisolated public let feedID: String
	nonisolated public let accountID: String
	nonisolated public let url: String
	nonisolated public let sidebarItemID: SidebarItemIdentifier?

	public weak var account: Account?

	public var defaultReadFilterType: ReadFilterType {
		.none
	}

	public var homePageURL: String? {
		get {
			settings.homePageURL
		}
		set {
			if let url = newValue, !url.isEmpty {
				settings.homePageURL = url.normalizedURL
			} else {
				settings.homePageURL = nil
			}
		}
	}

	// Note: this is available only if the icon URL was available in the feed.
	// The icon URL is a JSON-Feed-only feature.
	// Otherwise we find an icon URL via other means, but we don’t store it
	// as part of feed settings.
	public var iconURL: String? {
		get {
			settings.iconURL
		}
		set {
			settings.iconURL = newValue
		}
	}

	// Note: this is available only if the favicon URL was available in the feed.
	// The favicon URL is a JSON-Feed-only feature.
	// Otherwise we find a favicon URL via other means, but we don’t store it
	// as part of feed settings.
	public var faviconURL: String? {
		get {
			settings.faviconURL
		}
		set {
			settings.faviconURL = newValue
		}
	}

	@MainActor public var name: String? {
		didSet {
			if name != oldValue {
				postDisplayNameDidChangeNotification()
			}
		}
	}

	public var authors: Set<Author>? {
		get {
			if let authorsArray = settings.authors {
				return Set(authorsArray)
			}
			return nil
		}
		set {
			if let authorsSet = newValue {
				settings.authors = Array(authorsSet)
			} else {
				settings.authors = nil
			}
		}
	}

	@MainActor public var editedName: String? {
		// Don’t let editedName == ""
		get {
			guard let s = settings.editedName, !s.isEmpty else {
				return nil
			}
			return s
		}
		set {
			if newValue != editedName {
				if let valueToSet = newValue, !valueToSet.isEmpty {
					settings.editedName = valueToSet
				} else {
					settings.editedName = nil
				}
				postDisplayNameDidChangeNotification()
			}
		}
	}

	public var conditionalGetInfo: HTTPConditionalGetInfo? {
		get {
			settings.conditionalGetInfo
		}
		set {
			settings.conditionalGetInfo = newValue
		}
	}

	public var conditionalGetInfoDate: Date? {
		get {
			settings.conditionalGetInfoDate
		}
		set {
			settings.conditionalGetInfoDate = newValue
		}
	}

	public var cacheControlInfo: CacheControlInfo? {
		get {
			settings.cacheControlInfo
		}
		set {
			settings.cacheControlInfo = newValue
		}
	}

	public var contentHash: String? {
		get {
			settings.contentHash
		}
		set {
			settings.contentHash = newValue
		}
	}

	public var newArticleNotificationsEnabled: Bool {
		get {
			settings.newArticleNotificationsEnabled
		}
		set {
			settings.newArticleNotificationsEnabled = newValue
		}
	}

	public var readerViewAlwaysEnabled: Bool {
		get {
			settings.readerViewAlwaysEnabled
		}
		set {
			settings.readerViewAlwaysEnabled = newValue
		}
	}

	public var externalID: String? {
		get {
			settings.externalID
		}
		set {
			settings.externalID = newValue
		}
	}

	// Folder Name: Sync Service Relationship ID
	public var folderRelationship: [String: String]? {
		get {
			settings.folderRelationship
		}
		set {
			settings.folderRelationship = newValue
		}
	}

	/// Last time an attempt was made to read the feed.
	/// (Not necessarily a successful attempt.)
	public var lastCheckDate: Date? {
		get {
			settings.lastCheckDate
		}
		set {
			settings.lastCheckDate = newValue
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
		guard let account else {
			return
		}
		Task { @MainActor in
			do {
				try await account.renameFeed(self, name: newName)
				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	// MARK: - UnreadCountProvider

	public var unreadCount: Int {
		get {
			account?.unreadCount(for: self) ?? 0
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

	var settings: FeedSettings

	// MARK: - Init

	init(account: Account, url: String, settings: FeedSettings) {
		let accountID = account.accountID
		let feedID = settings.feedID
		self.accountID = accountID
		self.account = account
		self.feedID = feedID
		self.sidebarItemID = SidebarItemIdentifier.feed(accountID, feedID)

		self.url = url
		self.settings = settings
		self.settings.feed = self
	}

	// MARK: - API

	public func dropConditionalGetInfo() {
		conditionalGetInfo = nil
		contentHash = nil
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(feedID)
		hasher.combine(accountID)
	}

	// MARK: - Equatable

	public static func ==(lhs: Feed, rhs: Feed) -> Bool {
		lhs.feedID == rhs.feedID && lhs.accountID == rhs.accountID
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

@MainActor extension Set where Element == Feed {

	func feedIDs() -> Set<String> {
		Set<String>(map { $0.feedID })
	}

	func sorted() -> [Feed] {
		return sorted(by: { (feed1, feed2) -> Bool in
			if feed1.nameForDisplay.localizedStandardCompare(feed2.nameForDisplay) == .orderedSame {
				return feed1.url < feed2.url
			}
			return feed1.nameForDisplay.localizedStandardCompare(feed2.nameForDisplay) == .orderedAscending
		})
	}
}
