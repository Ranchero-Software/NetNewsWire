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

@MainActor final class IconImageCache {

	static var shared = IconImageCache()

	private var smartFeedIconImageCache = [SidebarItemIdentifier: IconImage]()
	private var feedIconImageCache = [SidebarItemIdentifier: IconImage]()
	private var faviconImageCache = [SidebarItemIdentifier: IconImage]()
	private var smallIconImageCache = [SidebarItemIdentifier: IconImage]()
	private var authorIconImageCache = [Author: IconImage]()

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
	}

	@objc func handleLowMemory(_ notification: Notification) {
		emptyCache()
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
						_ = AuthorAvatarDownloader.shared.image(for: author)
					}
				}
			}

			if let feed = article.feed, let feedID = feed.sidebarItemID, !feedsSeen.contains(feedID) {
				feedsSeen.insert(feedID)
				_ = FeedIconDownloader.shared.icon(for: feed)
				_ = FaviconDownloader.shared.faviconAsIcon(for: feed)
			}
		}
	}

	func prefetchImagesForFeeds(_ feeds: [Feed]) {
		for feed in feeds {
			_ = FeedIconDownloader.shared.icon(for: feed)
			_ = FaviconDownloader.shared.faviconAsIcon(for: feed)
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
		if let iconImage = feedIconImageCache[feedID] {
			return iconImage
		}
		if let iconImage = FeedIconDownloader.shared.cachedIcon(for: feed) {
			feedIconImageCache[feedID] = iconImage
			return iconImage
		}
		if let faviconImage = faviconImageCache[feedID] {
			return faviconImage
		}
		if let faviconImage = FaviconDownloader.shared.cachedFaviconAsIcon(for: feed) {
			faviconImageCache[feedID] = faviconImage
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
		if let iconImage = authorIconImageCache[author] {
			return iconImage
		}
		if let iconImage = AuthorAvatarDownloader.shared.cachedImage(for: author) {
			authorIconImageCache[author] = iconImage
			return iconImage
		}
		return nil
	}
}
