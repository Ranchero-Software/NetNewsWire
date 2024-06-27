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
import Images

@MainActor final class IconImageCache {

	static let shared = IconImageCache()

	private var smartFeedIconImageCache = [SidebarItemIdentifier: IconImage]()
	private var feedIconImageCache = [SidebarItemIdentifier: IconImage]()
	private var faviconImageCache = [SidebarItemIdentifier: IconImage]()
	private var smallIconImageCache = [SidebarItemIdentifier: IconImage]()
	private var authorIconImageCache = [Author: IconImage]()

	func imageFor(_ sidebarItemID: SidebarItemIdentifier) -> IconImage? {
		if let smartFeed = SmartFeedsController.shared.find(by: sidebarItemID) {
			return imageForFeed(smartFeed)
		}
		if let feed = AccountManager.shared.existingSidebarItem(with: sidebarItemID) {
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
		smartFeedIconImageCache = [SidebarItemIdentifier: IconImage]()
		feedIconImageCache = [SidebarItemIdentifier: IconImage]()
		faviconImageCache = [SidebarItemIdentifier: IconImage]()
		smallIconImageCache = [SidebarItemIdentifier: IconImage]()
		authorIconImageCache = [Author: IconImage]()
	}
}

private extension IconImageCache {
	
	func imageForSmartFeed(_ smartFeed: PseudoFeed, _ sidebarItemID: SidebarItemIdentifier) -> IconImage? {
		if let iconImage = smartFeedIconImageCache[sidebarItemID] {
			return iconImage
		}
		if let iconImage = smartFeed.smallIcon {
			smartFeedIconImageCache[sidebarItemID] = iconImage
			return iconImage
		}
		return nil
	}

	func imageForFeed(_ feed: Feed, _ sidebarItemID: SidebarItemIdentifier) -> IconImage? {
		if let iconImage = feedIconImageCache[sidebarItemID] {
			return iconImage
		}
		if let iconImage = FeedIconDownloader.shared.icon(for: feed) {
			feedIconImageCache[sidebarItemID] = iconImage
			return iconImage
		}
		if let faviconImage = faviconImageCache[sidebarItemID] {
			return faviconImage
		}
		if let faviconImage = FaviconDownloader.shared.faviconAsIcon(for: feed) {
			faviconImageCache[sidebarItemID] = faviconImage
			return faviconImage
		}
		return nil
	}

	func imageForSmallIconProvider(_ provider: SmallIconProvider, _ sidebarItemID: SidebarItemIdentifier) -> IconImage? {
		if let iconImage = smallIconImageCache[sidebarItemID] {
			return iconImage
		}
		if let iconImage = provider.smallIcon {
			smallIconImageCache[sidebarItemID] = iconImage
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
		if let iconImage = AuthorAvatarDownloader.shared.image(for: author) {
			authorIconImageCache[author] = iconImage
			return iconImage
		}
		return nil
	}
}
