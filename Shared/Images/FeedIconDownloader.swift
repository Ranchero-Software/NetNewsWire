//
//  FeedIconDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSCore
import RSWeb
import RSParser

extension Notification.Name {

	static let feedIconDidBecomeAvailable = Notification.Name("FeedIconDidBecomeAvailable") // UserInfoKey.feed
}

public final class FeedIconDownloader {

	public static let shared = FeedIconDownloader()

	private let imageDownloader = ImageDownloader.shared
	private var homePagesWithNoIconURL = Set<String>()
	private var cache = [WebFeed: IconImage]()
	private var waitingForFeedURLs = [String: WebFeed]()
	
	init() {

		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: imageDownloader)
	}

	func icon(for feed: WebFeed) -> IconImage? {

		if let cachedImage = cache[feed] {
			return cachedImage
		}
		
		if let homePageURLString = feed.homePageURL, let homePageURL = URL(string: homePageURLString), (homePageURL.host == "nnw.ranchero.com" || homePageURL.host == "netnewswire.blog") {
			return IconImage.appIcon
		}

		func checkHomePageURL() {
			guard let homePageURL = feed.homePageURL else {
				return
			}
			if homePagesWithNoIconURL.contains(homePageURL) {
				return
			}
			icon(forHomePageURL: homePageURL, feed: feed) { (image) in
				if let image {
					self.cache[feed] = IconImage(image)
					self.postFeedIconDidBecomeAvailableNotification(feed)
				}
			}
		}
		
		func checkFeedIconURL() {
			if let iconURL = feed.iconURL {
				icon(forURL: iconURL, feed: feed) { (image) in
					if let image = image {
						self.cache[feed] = IconImage(image)
						self.postFeedIconDidBecomeAvailableNotification(feed)
					} else {
						checkHomePageURL()
					}
				}
			} else {
				checkHomePageURL()
			}
		}

		checkFeedIconURL()

		return nil
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {
		guard let url = note.userInfo?[UserInfoKey.url] as? String, let feed = waitingForFeedURLs[url] else {
			return
		}
		waitingForFeedURLs[url] = nil
		_ = icon(for: feed)
	}
}

private extension FeedIconDownloader {

	static let homePagesWithUglyIcons: Set<String> = Set(["https://www.macsparky.com/", "https://xkcd.com/"])

	func icon(forHomePageURL homePageURL: String, feed: WebFeed, _ imageResultBlock: @escaping (RSImage?) -> Void) {

		if homePagesWithNoIconURL.contains(homePageURL) || Self.homePagesWithUglyIcons.contains(homePageURL) {
			imageResultBlock(nil)
			return
		}

		guard let metadata = HTMLMetadataDownloader.shared.cachedMetadata(for: homePageURL) else {
			imageResultBlock(nil)
			return
		}

		if let url = metadata.bestWebsiteIconURL() {
			homePagesWithNoIconURL.remove(homePageURL)
			icon(forURL: url, feed: feed, imageResultBlock)
			return
		}

		homePagesWithNoIconURL.insert(homePageURL)
	}

	func icon(forURL url: String, feed: WebFeed, _ imageResultBlock: @escaping (RSImage?) -> Void) {
		waitingForFeedURLs[url] = feed
		guard let imageData = imageDownloader.image(for: url) else {
			imageResultBlock(nil)
			return
		}
		RSImage.scaledForIcon(imageData, imageResultBlock: imageResultBlock)
	}

	func postFeedIconDidBecomeAvailableNotification(_ feed: WebFeed) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = [UserInfoKey.webFeed: feed]
			NotificationCenter.default.post(name: .feedIconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}
}
