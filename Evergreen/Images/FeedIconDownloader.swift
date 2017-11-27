//
//  FeedIconDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import Data
import RSWeb
import RSParser

public final class FeedIconDownloader {

	private let imageDownloader: ImageDownloader
	private var homePageToIconURLCache = [String: String]()
	private var homePagesWithNoIconURL = Set<String>()
	private var homePageDownloadsInProgress = Set<String>()

	init(imageDownloader: ImageDownloader) {

		self.imageDownloader = imageDownloader
	}

	func icon(for feed: Feed) -> NSImage? {

		if let iconURL = feed.iconURL {
			return icon(forURL: iconURL)
		}

		if let homePageURL = feed.homePageURL {
			return icon(forHomePageURL: homePageURL)
		}

		return nil
	}

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
}

private extension FeedIconDownloader {

	func cachedIconURL(for homePageURL: String) -> String? {

		return homePageToIconURLCache[homePageURL]
	}

	func cacheIconURL(for homePageURL: String, _ iconURL: String) {

		homePagesWithNoIconURL.remove(homePageURL)
		homePageToIconURLCache[homePageURL] = iconURL
	}

	func findIconURLForHomePageURL(_ homePageURL: String) {

		guard !homePageDownloadsInProgress.contains(homePageURL) else {
			return
		}
		homePageDownloadsInProgress.insert(homePageURL)

		HTMLMetadataDownloader.downloadMetadata(for: homePageURL) { (metadata) in

			self.homePageDownloadsInProgress.remove(homePageURL)
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
