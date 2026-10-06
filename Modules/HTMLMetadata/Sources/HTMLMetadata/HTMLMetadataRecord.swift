//
//  HTMLMetadataRecord.swift
//  HTMLMetadata
//
//  Created by Brent Simmons on 4/6/26.
//

import Foundation
import RSParser

public struct HTMLMetadataRecord: Sendable {

	public let url: String
	public let favicons: [Favicon]
	public let appleTouchIcons: [AppleTouchIcon]
	public let feedLinks: [FeedLink]
	public let openGraphImages: [OpenGraphImage]
	public let twitterImageURL: String?

	init(url: String, favicons: [Favicon], appleTouchIcons: [AppleTouchIcon],
	     feedLinks: [FeedLink], openGraphImages: [OpenGraphImage],
	     twitterImageURL: String?) {
		self.url = url
		self.favicons = favicons
		self.appleTouchIcons = appleTouchIcons
		self.feedLinks = feedLinks
		self.openGraphImages = openGraphImages
		self.twitterImageURL = twitterImageURL
	}

	public init(url: String, metadata: HTMLMetadata) {
		self.url = url

		self.favicons = metadata.favicons.map { favicon in
			Favicon(type: favicon.type, urlString: favicon.urlString)
		}

		self.appleTouchIcons = metadata.appleTouchIcons.map { icon in
			AppleTouchIcon(
				rel: icon.rel,
				sizes: icon.sizes,
				width: icon.size.width,
				height: icon.size.height,
				urlString: icon.urlString
			)
		}

		self.feedLinks = metadata.feedLinks.map { link in
			FeedLink(title: link.title, type: link.type, urlString: link.urlString)
		}

		self.openGraphImages = metadata.openGraphProperties.images.map { image in
			OpenGraphImage(
				url: image.url,
				secureURL: image.secureURL,
				mimeType: image.mimeType,
				width: image.width,
				height: image.height,
				altText: image.altText
			)
		}

		self.twitterImageURL = metadata.twitterProperties.imageURL
	}
}

// MARK: - Nested Types

public extension HTMLMetadataRecord {

	struct Favicon: Codable, Sendable {
		public let type: String?
		public let urlString: String?
	}

	struct AppleTouchIcon: Codable, Sendable {
		public let rel: String?
		public let sizes: String?
		public let width: CGFloat
		public let height: CGFloat
		public let urlString: String?
	}

	struct FeedLink: Codable, Sendable {
		public let title: String?
		public let type: String?
		public let urlString: String?
	}

	struct OpenGraphImage: Codable, Sendable {
		public let url: String?
		public let secureURL: String?
		public let mimeType: String?
		public let width: CGFloat
		public let height: CGFloat
		public let altText: String?
	}
}

// MARK: - Icon Selection

public extension HTMLMetadataRecord {

	func bestWebsiteIconURL() -> String? {
		if let appleTouchIcon = largestAppleTouchIcon() {
			return appleTouchIcon
		}
		if let openGraphImageURL = largestOpenGraphImageURL() {
			return openGraphImageURL
		}
		return twitterImageURL
	}

	func largestOpenGraphImageURL() -> String? {
		guard !openGraphImages.isEmpty else {
			return nil
		}

		var bestImage: OpenGraphImage?

		for image in openGraphImages {
			if image.height > 0 && image.width / image.height > 2 {
				continue
			}
			if bestImage == nil {
				bestImage = image
				continue
			}
			if let best = bestImage, image.height > best.height && image.width > best.width {
				bestImage = image
			}
		}

		guard let url = bestImage?.secureURL ?? bestImage?.url else {
			return nil
		}

		let badURLs: Set<String> = ["https://s0.wp.com/i/blank.jpg"]
		guard !badURLs.contains(url) else {
			return nil
		}

		return url
	}

	func largestAppleTouchIcon() -> String? {
		guard !appleTouchIcons.isEmpty else {
			return nil
		}

		var bestImage: AppleTouchIcon?

		for image in appleTouchIcons {
			if image.height > 0 && image.width / image.height > 2 {
				continue
			}
			if bestImage == nil {
				bestImage = image
				continue
			}
			if let best = bestImage, image.height > best.height && image.width > best.width {
				bestImage = image
			}
		}

		return bestImage?.urlString
	}
}
