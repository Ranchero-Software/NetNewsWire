//
//  FeedIconDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Account
import RSCore
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
	private var cache = [Feed: RSImage]()

	init(imageDownloader: ImageDownloader) {

		self.imageDownloader = imageDownloader
	}

	func icon(for feed: Feed) -> RSImage? {

		if let cachedImage = cache[feed] {
			return cachedImage
		}
		
		if let iconURL = feed.iconURL {
			icon(forURL: iconURL) { (image) in
				if let image = image {
					self.postFeedIconDidBecomeAvailableNotification(feed)
					self.cache[feed] = image
				}
				else {
					checkHomePageURL()
				}
			}
		}

		func checkHomePageURL() {
			guard let homePageURL = feed.homePageURL else {
				return
			}
			icon(forHomePageURL: homePageURL) { (image) in
				if let image = image {
					self.postFeedIconDidBecomeAvailableNotification(feed)
					self.cache[feed] = image
				}
			}
		}

		return nil
	}
}

private extension FeedIconDownloader {

	func icon(forHomePageURL homePageURL: String, _ imageResultBlock: @escaping (RSImage?) -> Void) {

		if homePagesWithNoIconURL.contains(homePageURL) {
			imageResultBlock(nil)
			return
		}

		if let iconURL = cachedIconURL(for: homePageURL) {
			icon(forURL: iconURL, imageResultBlock)
			return
		}

		findIconURLForHomePageURL(homePageURL)
	}

	func icon(forURL url: String, _ imageResultBlock: @escaping (RSImage?) -> Void) {
		guard let imageData = imageDownloader.image(for: url) else {
			imageResultBlock(nil)
			return
		}
		RSImage.scaledForAvatar(imageData, imageResultBlock: imageResultBlock)
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
			icon(forURL: url) { (image) in
			}
			return
		}

		homePagesWithNoIconURL.insert(homePageURL)
	}
}
