//
//  HTMLMetadata.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

import CoreGraphics
import Foundation

// Structured view of the data gathered from an HTML document by `HTMLMetadataParser`.
// Sendable plain-value types throughout.

public struct HTMLMetadata: Sendable {

	public let baseURLString: String
	public let tags: [HTMLTag]
	public let favicons: [HTMLMetadataFavicon]
	public let appleTouchIcons: [HTMLMetadataAppleTouchIcon]
	public let feedLinks: [HTMLMetadataFeedLink]
	public let openGraphProperties: HTMLOpenGraphProperties
	public let twitterProperties: HTMLTwitterProperties

	public init(urlString: String, tags: [HTMLTag]) {
		self.baseURLString = urlString
		self.tags = tags
		self.favicons = Self.resolveFavicons(tags: tags, baseURLString: urlString)
		self.appleTouchIcons = Self.resolveAppleTouchIcons(tags: tags, baseURLString: urlString)
		self.feedLinks = Self.resolveFeedLinks(tags: tags, baseURLString: urlString)
		self.openGraphProperties = HTMLOpenGraphProperties(tags: tags)
		self.twitterProperties = HTMLTwitterProperties(tags: tags)
	}
}

public struct HTMLMetadataFeedLink: Sendable {
	public let title: String?
	public let type: String?
	public let urlString: String?   // absolute
}

public struct HTMLMetadataFavicon: Sendable {
	public let type: String?
	public let urlString: String?   // absolute
}

public struct HTMLMetadataAppleTouchIcon: Sendable {
	public let rel: String?
	public let sizes: String?
	public let size: CGSize
	public let urlString: String?   // absolute
}

public struct HTMLOpenGraphProperties: Sendable {
	public let images: [HTMLOpenGraphImage]

	init(tags: [HTMLTag]) {
		self.images = HTMLOpenGraphProperties.parse(tags: tags)
	}
}

public struct HTMLOpenGraphImage: Sendable {
	public var url: String?
	public var secureURL: String?
	public var mimeType: String?
	public var width: CGFloat
	public var height: CGFloat
	public var altText: String?
}

public struct HTMLTwitterProperties: Sendable {
	public let imageURL: String?

	init(tags: [HTMLTag]) {
		self.imageURL = HTMLTwitterProperties.findImageURL(tags: tags)
	}
}

// MARK: - Categorization

private extension HTMLMetadata {

	static let iconRel = "icon"
	static let appleTouchIcon = "apple-touch-icon"
	static let appleTouchIconPrecomposed = "apple-touch-icon-precomposed"
	static let alternateRel = "alternate"
	static let feedTypeSuffixes = ["/rss+xml", "/atom+xml", "/json"]

	static func resolveFavicons(tags: [HTMLTag], baseURLString: String) -> [HTMLMetadataFavicon] {
		let matching = tags.filter { tag in
			tag.type == .link
				&& !(urlString(from: tag.attributes) ?? "").isEmpty
				&& relValues(in: tag.attributes).contains { $0.caseInsensitiveCompare(iconRel) == .orderedSame }
		}

		var seen = Set<String>()
		var result = [HTMLMetadataFavicon]()
		for tag in matching {
			let absolute = absoluteURLString(from: tag.attributes, baseURLString: baseURLString)
			guard let absolute, !seen.contains(absolute) else {
				continue
			}
			seen.insert(absolute)
			let type = tag.attributes.caseInsensitiveValue(forKey: "type")
			result.append(HTMLMetadataFavicon(type: type, urlString: absolute))
		}
		return result
	}

	static func resolveAppleTouchIcons(tags: [HTMLTag], baseURLString: String) -> [HTMLMetadataAppleTouchIcon] {
		let matching = tags.filter { tag in
			guard tag.type == .link else {
				return false
			}
			let rel = (tag.attributes.caseInsensitiveValue(forKey: "rel") ?? "").lowercased()
			return rel == appleTouchIcon || rel == appleTouchIconPrecomposed
		}

		return matching.map { tag in
			let absolute = absoluteURLString(from: tag.attributes, baseURLString: baseURLString)
			let sizes = tag.attributes.caseInsensitiveValue(forKey: "sizes")
			let rel = tag.attributes.caseInsensitiveValue(forKey: "rel")
			let size = parsedSize(sizes: sizes)
			return HTMLMetadataAppleTouchIcon(rel: rel, sizes: sizes, size: size, urlString: absolute)
		}
	}

	static func resolveFeedLinks(tags: [HTMLTag], baseURLString: String) -> [HTMLMetadataFeedLink] {
		let matching = tags.filter { tag in
			guard tag.type == .link else {
				return false
			}
			let rel = (tag.attributes.caseInsensitiveValue(forKey: "rel") ?? "").lowercased()
			guard rel == alternateRel else {
				return false
			}
			// Exclude `rel="alternate"` variants that are definitely-not-feeds —
			// responsive-design mobile links use `media=`, i18n variants use
			// `hreflang=`. Without this, pages that advertise mobile alternates
			// (YouTube) would leak those into feed auto-discovery when we
			// loosened the type requirement below.
			if let media = tag.attributes.caseInsensitiveValue(forKey: "media"), !media.isEmpty {
				return false
			}
			if let hreflang = tag.attributes.caseInsensitiveValue(forKey: "hreflang"), !hreflang.isEmpty {
				return false
			}
			// Accept feed-typed alternates AND typeless alternates — some pages
			// advertise their RSS/Atom feed with `<link rel="alternate" href="…">`
			// and no type attribute. Excluding those made auto-discovery fail
			// for such sites. An explicit non-feed type (e.g. `text/html`) is
			// still filtered out.
			if let type = tag.attributes.caseInsensitiveValue(forKey: "type"), !type.isEmpty {
				guard isFeedType(type) else {
					return false
				}
			}
			// Require an http(s) URL — skip app-scheme alternates like
			// `android-app://` / `ios-app://` which aren't feed URLs.
			guard let url = urlString(from: tag.attributes), !url.isEmpty else {
				return false
			}
			let lower = url.lowercased()
			return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("/") || lower.hasPrefix(".") || !lower.contains(":")
		}

		return matching.map { tag in
			let absolute = absoluteURLString(from: tag.attributes, baseURLString: baseURLString)
			let title = tag.attributes.caseInsensitiveValue(forKey: "title")
			let type = tag.attributes.caseInsensitiveValue(forKey: "type")
			return HTMLMetadataFeedLink(title: title, type: type, urlString: absolute)
		}
	}

	static func relValues(in attributes: [String: String]) -> [String] {
		guard let rel = attributes.caseInsensitiveValue(forKey: "rel") else {
			return []
		}
		return rel.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
	}

	static func urlString(from attributes: [String: String]) -> String? {
		attributes.caseInsensitiveValue(forKey: "href")
			?? attributes.caseInsensitiveValue(forKey: "src")
	}

	static func absoluteURLString(from attributes: [String: String], baseURLString: String) -> String? {
		guard let relative = urlString(from: attributes), !relative.isEmpty else {
			return nil
		}
		guard let baseURL = URL(string: baseURLString),
		      let absoluteURL = URL(string: relative, relativeTo: baseURL) else {
			return nil
		}
		return absoluteURL.absoluteURL.standardized.absoluteString
	}

	static func isFeedType(_ type: String) -> Bool {
		let lowered = type.lowercased()
		return feedTypeSuffixes.contains { lowered.hasSuffix($0) }
	}

	static func parsedSize(sizes: String?) -> CGSize {
		guard let sizes else {
			return .zero
		}
		let parts = sizes.components(separatedBy: "x")
		guard parts.count == 2,
		      let width = Double(parts[0]),
		      let height = Double(parts[1]) else {
			return .zero
		}
		return CGSize(width: width, height: height)
	}
}

// MARK: - Open Graph

private extension HTMLOpenGraphProperties {

	static let ogPrefix = "og:"
	static let ogImage = "og:image"
	static let ogImageURL = "og:image:url"
	static let ogImageSecureURL = "og:image:secure_url"
	static let ogImageType = "og:image:type"
	static let ogImageWidth = "og:image:width"
	static let ogImageHeight = "og:image:height"
	static let ogImageAlt = "og:image:alt"

	static func parse(tags: [HTMLTag]) -> [HTMLOpenGraphImage] {
		var images: [HTMLOpenGraphImage] = []

		func currentImage() -> HTMLOpenGraphImage? {
			images.last
		}

		func pushImage() -> Int {
			images.append(HTMLOpenGraphImage(url: nil, secureURL: nil, mimeType: nil, width: 0, height: 0, altText: nil))
			return images.count - 1
		}

		func ensureImageIndex() -> Int {
			if images.isEmpty {
				return pushImage()
			}
			return images.count - 1
		}

		for tag in tags {
			guard tag.type == .meta else {
				continue
			}
			guard let propertyName = tag.attributes["property"],
			      propertyName.hasPrefix(ogPrefix) else {
				continue
			}
			guard let content = tag.attributes["content"] else {
				continue
			}

			switch propertyName {
			case ogImage:
				// Most likely case: og:image starts a fresh image entry.
				if let image = currentImage(), image.url == nil {
					images[images.count - 1].url = content
				} else {
					_ = pushImage()
					images[images.count - 1].url = content
				}
			case ogImageURL:
				images[ensureImageIndex()].url = content
			case ogImageSecureURL:
				images[ensureImageIndex()].secureURL = content
			case ogImageType:
				images[ensureImageIndex()].mimeType = content
			case ogImageAlt:
				images[ensureImageIndex()].altText = content
			case ogImageWidth:
				images[ensureImageIndex()].width = CGFloat(Double(content) ?? 0)
			case ogImageHeight:
				images[ensureImageIndex()].height = CGFloat(Double(content) ?? 0)
			default:
				break
			}
		}

		return images
	}
}

// MARK: - Twitter

private extension HTMLTwitterProperties {

	static let twitterImageSrc = "twitter:image:src"

	static func findImageURL(tags: [HTMLTag]) -> String? {
		for tag in tags {
			guard tag.type == .meta,
			      tag.attributes["name"] == twitterImageSrc,
			      let content = tag.attributes["content"],
			      !content.isEmpty else {
				continue
			}
			return content
		}
		return nil
	}
}

// MARK: - Dictionary case-insensitive lookup

private extension Dictionary where Key == String, Value == String {

	func caseInsensitiveValue(forKey key: String) -> String? {
		if let value = self[key] {
			return value
		}
		for (k, v) in self where k.caseInsensitiveCompare(key) == .orderedSame {
			return v
		}
		return nil
	}
}
