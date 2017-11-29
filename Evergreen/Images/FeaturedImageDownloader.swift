//
//  FeaturedImageDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import Data
import RSParser

final class FeaturedImageDownloader {

	private let imageDownloader: ImageDownloader
	private var articleURLToFeaturedImageURLCache = [String: String]()
	private var articleURLsWithNoFeaturedImage = Set<String>()
	private var urlsInProgress = Set<String>()

	init(imageDownloader: ImageDownloader) {

		self.imageDownloader = imageDownloader
	}

	func image(for article: Article) -> NSImage? {

		if let url = article.imageURL {
			return image(forFeaturedImageURL: url)
		}
		if let articleURL = article.url {
			return image(forArticleURL: articleURL)
		}
		return nil
	}

	func image(forArticleURL articleURL: String) -> NSImage? {

		if articleURLsWithNoFeaturedImage.contains(articleURL) {
			return nil
		}

		if let featuredImageURL = cachedURL(for: articleURL) {
			return image(forFeaturedImageURL: featuredImageURL)
		}
		findFeaturedImageURL(for: articleURL)
		return nil
	}

	func image(forFeaturedImageURL featuredImageURL: String) -> NSImage? {

		return imageDownloader.image(for: featuredImageURL)
	}
}

private extension FeaturedImageDownloader {

	func cachedURL(for articleURL: String) -> String? {

		return articleURLToFeaturedImageURLCache[articleURL]
	}

	func cacheURL(for articleURL: String, _ featuredImageURL: String) {

		articleURLsWithNoFeaturedImage.remove(articleURL)
		articleURLToFeaturedImageURLCache[articleURL] = featuredImageURL
	}

	func findFeaturedImageURL(for articleURL: String) {

		guard !urlsInProgress.contains(articleURL) else {
			return
		}
		urlsInProgress.insert(articleURL)

		HTMLMetadataDownloader.downloadMetadata(for: articleURL) { (metadata) in

			self.urlsInProgress.remove(articleURL)

			guard let metadata = metadata else {
				return
			}
			self.pullFeaturedImageURL(from: metadata, articleURL: articleURL)
		}
	}

	func pullFeaturedImageURL(from metadata: RSHTMLMetadata, articleURL: String) {

		if let url = metadata.bestFeaturedImageURL() {
			cacheURL(for: articleURL, url)
			let _ = image(forFeaturedImageURL: url)
			return
		}

		articleURLsWithNoFeaturedImage.insert(articleURL)
	}
}
