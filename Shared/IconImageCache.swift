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

class IconImageCache {

	static var shared = IconImageCache()

	private var smartFeedIconImageCache = [FeedIdentifier: IconImage]()
	private var webFeedIconImageCache = [FeedIdentifier: IconImage]()
	private var faviconImageCache = [FeedIdentifier: IconImage]()
	private var smallIconImageCache = [FeedIdentifier: IconImage]()
	private var authorIconImageCache = [Author: IconImage]()

	func imageFor(_ feedID: FeedIdentifier) -> IconImage? {
		if let smartFeed = SmartFeedsController.shared.find(by: feedID) {
			return imageForFeed(smartFeed)
		}
		if let feed = AccountManager.shared.existingFeed(with: feedID) {
			return imageForFeed(feed)
		}
		return nil
	}

	func imageForFeed(_ feed: Feed) -> IconImage? {
		guard let feedID = feed.feedID else {
			return nil
		}
		
		if let smartFeed = feed as? PseudoFeed {
			return imageForSmartFeed(smartFeed, feedID)
		}
		if let webFeed = feed as? WebFeed, let iconImage = imageForWebFeed(webFeed, feedID) {
			return iconImage
		}
		if let smallIconProvider = feed as? SmallIconProvider {
			return imageForSmallIconProvider(smallIconProvider, feedID)
		}

		return nil
	}

	func imageForArticle(_ article: Article) -> IconImage? {
		if let iconImage = imageForAuthors(article.authors) {
			return iconImage
		}
		guard let feed = article.webFeed else {
			return nil
		}
		return imageForFeed(feed)
	}

	func emptyCache() {
		smartFeedIconImageCache = [FeedIdentifier: IconImage]()
		webFeedIconImageCache = [FeedIdentifier: IconImage]()
		faviconImageCache = [FeedIdentifier: IconImage]()
		smallIconImageCache = [FeedIdentifier: IconImage]()
		authorIconImageCache = [Author: IconImage]()
	}
}

private extension IconImageCache {
	
	func imageForSmartFeed(_ smartFeed: PseudoFeed, _ feedID: FeedIdentifier) -> IconImage? {
		if let iconImage = smartFeedIconImageCache[feedID] {
			return iconImage
		}
		if let iconImage = smartFeed.smallIcon {
			smartFeedIconImageCache[feedID] = iconImage
			return iconImage
		}
		return nil
	}

	func imageForWebFeed(_ webFeed: WebFeed, _ feedID: FeedIdentifier) -> IconImage? {
		if let iconImage = webFeedIconImageCache[feedID] {
			return iconImage
		}
		if let iconImage = appDelegate.webFeedIconDownloader.icon(for: webFeed) {
			webFeedIconImageCache[feedID] = iconImage
			return iconImage
		}
		if let faviconImage = faviconImageCache[feedID] {
			return faviconImage
		}
		if let faviconImage = appDelegate.faviconDownloader.faviconAsIcon(for: webFeed) {
			faviconImageCache[feedID] = faviconImage
			return faviconImage
		}
		return nil
	}

	func imageForSmallIconProvider(_ provider: SmallIconProvider, _ feedID: FeedIdentifier) -> IconImage? {
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
		if let iconImage = appDelegate.authorAvatarDownloader.image(for: author) {
			authorIconImageCache[author] = iconImage
			return iconImage
		}
		return nil
	}
}
