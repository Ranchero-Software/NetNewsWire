//
//  FeedIconDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import Articles
import Account
import RSWeb
import RSParser

extension Notification.Name {

	static let FeedIconDidBecomeAvailable = Notification.Name("FeedIconDidBecomeAvailableNotification") // UserInfoKey.feed
}

public final class FeedIconDownloader {

	private let imageDownloader: ImageDownloader
	private var homePageToIconURLCache = [String: String]()
	private var homePagesWithNoIconURL = Set<String>()
	private var urlsInProgress = Set<String>()
	private var cache = [Feed: NSImage]()

	init(imageDownloader: ImageDownloader) {

		self.imageDownloader = imageDownloader
	}

	func icon(for feed: Feed) -> NSImage? {

		if let cachedImage = cache[feed] {
			return cachedImage
		}
		
		if let iconURL = feed.iconURL {
			if let image = icon(forURL: iconURL) {
				postFeedIconDidBecomeAvailableNotification(feed)
				cache[feed] = image
				return image
			}
		}

		if let homePageURL = feed.homePageURL {
			if let image = icon(forHomePageURL: homePageURL) {
				postFeedIconDidBecomeAvailableNotification(feed)
				cache[feed] = image
				return image
			}
		}

		return nil
	}
}

private extension FeedIconDownloader {

	func icon(forHomePageURL homePageURL: String) -> NSImage? {

		if homePagesWithNoIconURL.contains(homePageURL) {
			return nil
		}

		if let iconURL = cachedIconURL(for: homePageURL) {
			return icon(forURL: iconURL)
		}

		findIconURLForHomePageURL(homePageURL)
		return nil
	}

	func icon(forURL url: String) -> NSImage? {

		return imageDownloader.image(for: url)
	}

	func postFeedIconDidBecomeAvailableNotification(_ feed: Feed) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = [UserInfoKey.feed: feed]
			NotificationCenter.default.post(name: .FeedIconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}

	func cachedIconURL(for homePageURL: String) -> String? {

		return homePageToIconURLCache[homePageURL]
	}

	func cacheIconURL(for homePageURL: String, _ iconURL: String) {

		homePagesWithNoIconURL.remove(homePageURL)
		homePageToIconURLCache[homePageURL] = iconURL
	}

	func findIconURLForHomePageURL(_ homePageURL: String) {

		guard !urlsInProgress.contains(homePageURL) else {
			return
		}
		urlsInProgress.insert(homePageURL)

		HTMLMetadataDownloader.downloadMetadata(for: homePageURL) { (metadata) in

			self.urlsInProgress.remove(homePageURL)
			guard let metadata = metadata else {
				return
			}
			self.pullIconURL(from: metadata, homePageURL: homePageURL)
		}
	}

	func pullIconURL(from metadata: RSHTMLMetadata, homePageURL: String) {

		if let url = metadata.bestWebsiteIconURL() {
			cacheIconURL(for: homePageURL, url)
			let _ = icon(forURL: url)
			return
		}

		homePagesWithNoIconURL.insert(homePageURL)
	}
}
