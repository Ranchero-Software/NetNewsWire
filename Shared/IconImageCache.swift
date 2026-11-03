//
//  IconImageCache.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 5/2/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Articles
import RSCore
import Images

extension Notification.Name {
	/// Posted when a feed’s feed icon or home page icon loads, fails, or changes. userInfo key: `UserInfoKey.feed`.
	static let feedIconDidBecomeAvailable = Notification.Name("FeedIconDidBecomeAvailable")
}

@MainActor final class IconImageCache {

	static var shared = IconImageCache()

	private var smartFeedIconImageCache = [SidebarItemIdentifier: IconImage]()
	private var feedIconImageCache = [SidebarItemIdentifier: IconImage]()
	private var faviconImageCache = [SidebarItemIdentifier: IconImage]()
	private var smallIconImageCache = [SidebarItemIdentifier: IconImage]()
	private var authorIconImageCache = [Author: IconImage]()

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleFeedIconDidChange(_:)), name: .feedIconDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleHomePageIconDidChange(_:)), name: .homePageIconDidChange, object: nil)
	}

	@objc func handleLowMemory(_ notification: Notification) {
		emptyCache()
	}

	@objc func handleFeedIconDidChange(_ notification: Notification) {
		guard let feed = notification.userInfo?[FeedIconDownloader.feedKey] as? Feed else {
			return
		}
		postFeedIconDidBecomeAvailable(feed)
	}

	@objc func handleHomePageIconDidChange(_ notification: Notification) {
		guard let feeds = notification.userInfo?[HomePageIconDownloader.feedsKey] as? Set<Feed> else {
			return
		}
		for feed in feeds {
			postFeedIconDidBecomeAvailable(feed)
		}
	}

	func imageFor(_ feedID: SidebarItemIdentifier) -> IconImage? {
		if let smartFeed = SmartFeedsController.shared.find(by: feedID) {
			return imageForFeed(smartFeed)
		}
		if let feed = AccountManager.shared.existingFeed(with: feedID) {
			return imageForFeed(feed)
		}
		return nil
	}

	func imageForFeed(_ sidebarItem: SidebarItem) -> IconImage? {
		guard let sidebarItemID = sidebarItem.sidebarItemID else {
			return nil
		}

		if let smartFeed = sidebarItem as? PseudoFeed {
			return imageForSmartFeed(smartFeed, sidebarItemID)
		}
		if let feed = sidebarItem as? Feed, let iconImage = imageForFeed(feed, sidebarItemID) {
			return iconImage
		}
		if let smallIconProvider = sidebarItem as? SmallIconProvider {
			return imageForSmallIconProvider(smallIconProvider, sidebarItemID)
		}

		return nil
	}

	func prefetchImagesForArticles(_ articles: ArticleArray) {

		var feedsSeen = Set<SidebarItemIdentifier>()
		var authorsSeen = Set<String>()

		for article in articles {
			if let authors = article.authors {
				for author in authors {
					if let avatarURL = author.avatarURL, !authorsSeen.contains(avatarURL) {
						authorsSeen.insert(avatarURL)
						_ = AuthorAvatarDownloader.shared.avatar(for: author)
					}
				}
			}

			if let feed = article.feed, let feedID = feed.sidebarItemID, !feedsSeen.contains(feedID) {
				feedsSeen.insert(feedID)
				_ = feedOrHomePageIcon(feed)
				_ = FaviconDownloader.shared.favicon(for: feed)
			}
		}
	}

	func prefetchImagesForFeeds(_ feeds: [Feed]) {
		for feed in feeds {
			_ = feedOrHomePageIcon(feed)
			_ = FaviconDownloader.shared.favicon(for: feed)
		}
	}

	func imageForArticle(_ article: Article) -> IconImage? {
		if let iconImage = imageForAuthors(article.authors) {
			return iconImage
		}
		guard let feed = article.feed else {
			return nil
		}
		return imageForFeed(feed)
	}

	func emptyCache() {
		smartFeedIconImageCache.removeAll()
		feedIconImageCache.removeAll()
		faviconImageCache.removeAll()
		smallIconImageCache.removeAll()
		authorIconImageCache.removeAll()
	}
}

private extension IconImageCache {

	static func isNetNewsWireBrandedFeed(_ feed: Feed) -> Bool {
		if let homePageURLString = feed.homePageURL, let homePageURL = URL(string: homePageURLString), let host = homePageURL.host {
			if host == "nnw.ranchero.com" || host == "netnewswire.blog" || host.hasSuffix("netnewswire.com") {
				return true
			}
		}
		return feed.url.hasPrefix("https://ranchero.com/downloads/netnewswire")
	}

	/// Precedence: feed icon, then home page icon.
	/// A feed icon that’s loading keeps the home page icon from being looked up.
	func feedOrHomePageIcon(_ feed: Feed) -> IconLookup {
		let feedIcon = FeedIconDownloader.shared.feedIcon(for: feed)
		guard case .unavailable = feedIcon else {
			return feedIcon
		}
		return HomePageIconDownloader.shared.homePageIcon(for: feed)
	}

	func postFeedIconDidBecomeAvailable(_ feed: Feed) {
		NotificationCenter.default.post(name: .feedIconDidBecomeAvailable, object: self, userInfo: [UserInfoKey.feed: feed])
	}

	func imageForSmartFeed(_ smartFeed: PseudoFeed, _ feedID: SidebarItemIdentifier) -> IconImage? {
		if let iconImage = smartFeedIconImageCache[feedID] {
			return iconImage
		}
		if let iconImage = smartFeed.smallIcon {
			smartFeedIconImageCache[feedID] = iconImage
			return iconImage
		}
		return nil
	}

	func imageForFeed(_ feed: Feed, _ feedID: SidebarItemIdentifier) -> IconImage? {
		if Self.isNetNewsWireBrandedFeed(feed) {
			return IconImage.nnwFeedIcon
		}

		// The downloaders are the source of truth — consult them ahead of the local
		// dictionaries so a newly arrived icon replaces a stale one. The dictionaries
		// keep the last known icons across the downloaders’ low-memory and background flushes.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/5376>
		// A miss requests the feed icon, so it comes back after a flush without waiting for a prefetch.
		if let iconImage = feedOrHomePageIcon(feed).iconImage {
			feedIconImageCache[feedID] = iconImage
			return iconImage
		}
		if let iconImage = feedIconImageCache[feedID] {
			return iconImage
		}
		if let faviconImage = FaviconDownloader.shared.favicon(for: feed).iconImage {
			faviconImageCache[feedID] = faviconImage
			return faviconImage
		}
		if let faviconImage = faviconImageCache[feedID] {
			return faviconImage
		}
		return nil
	}

	func imageForSmallIconProvider(_ provider: SmallIconProvider, _ feedID: SidebarItemIdentifier) -> IconImage? {
		if let iconImage = smallIconImageCache[feedID] {
			return iconImage
		}
		if let iconImage = provider.smallIcon {
			smallIconImageCache[feedID] = iconImage
			return iconImage
		}
		return nil
	}

	func imageForAuthors(_ authors: Set<Author>?) -> IconImage? {
		guard let authors = authors, authors.count == 1, let author = authors.first else {
			return nil
		}
		return imageForAuthor(author)
	}

	func imageForAuthor(_ author: Author) -> IconImage? {
		if let iconImage = AuthorAvatarDownloader.shared.avatar(for: author).iconImage {
			authorIconImageCache[author] = iconImage
			return iconImage
		}
		return authorIconImageCache[author]
	}
}
