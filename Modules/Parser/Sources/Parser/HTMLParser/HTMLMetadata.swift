//
//  HTMLMetadata.swift
//
//
//  Created by Brent Simmons on 9/22/24.
//

import Foundation

public final class HTMLMetadata: Sendable {

	public let baseURLString: String
	public let tags: [HTMLTag]
	public let favicons: [HTMLMetadataFavicon]?
	public let appleTouchIcons: [HTMLMetadataAppleTouchIcon]?
	public let feedLinks: [HTMLMetadataFeedLink]?
	public let openGraphProperties: HTMLOpenGraphProperties?
	public let twitterProperties: HTMLTwitterProperties?

	init(_ urlString: String, _ tags: [HTMLTag]) {

		self.baseURLString = urlString
		self.tags = tags

		self.favicons = Self.resolvedFaviconLinks(urlString, tags)

		if let appleTouchIconTags = Self.appleTouchIconTags(tags) {
			self.appleTouchIcons = appleTouchIconTags.map { htmlTag in
				HTMLMetadataAppleTouchIcon(urlString, htmlTag)
			}
		}
		else {
			self.appleTouchIcons = nil
		}

		if let feedLinkTags = Self.feedLinkTags(tags) {
			self.feedLinks = feedLinkTags.map { htmlTag in
				HTMLMetadataFeedLink(urlString, htmlTag)
			}
		}
		else {
			self.feedLinks = nil
		}

		self.openGraphProperties = HTMLOpenGraphProperties(urlString, tags)
		self.twitterProperties = HTMLTwitterProperties(urlString, tags)
	}

	static func resolvedFaviconLinks(_ baseURLString: String, _ tags: [HTMLTag]) -> [HTMLMetadataFavicon]? {

		guard let linkTags = linkTagsWithMatchingRel("icon", tags) else {
			return nil
		}

		var seenHrefs = [String]()

		let favicons: [HTMLMetadataFavicon] = linkTags.compactMap { htmlTag in

			let favicon = HTMLMetadataFavicon(baseURLString, htmlTag)
			guard let urlString = favicon.urlString else {
				return nil
			}
			guard !seenHrefs.contains(urlString) else {
				return nil
			}
			seenHrefs.append(urlString)
			return favicon
		}

		return favicons.isEmpty ? nil : favicons
	}

	static func appleTouchIconTags(_ tags: [HTMLTag]) -> [HTMLTag]? {

		guard let linkTags = linkTags(tags) else {
			return nil
		}

		guard let appleTouchIconTags = tagsMatchingRelValues(["apple-touch-icon", "apple-touch-icon-precomposed"], linkTags) else {
			return nil
		}
		return appleTouchIconTags.isEmpty ? nil : appleTouchIconTags
	}

	static func feedLinkTags(_ tags: [HTMLTag]) -> [HTMLTag]? {

		guard let alternateLinkTags = linkTagsWithMatchingRel("alternate", tags) else {
			return nil
		}

		let feedLinkTags = alternateLinkTags.filter { tag in
			
			guard let attributes = tag.attributes, let type = attributes.object(forCaseInsensitiveKey: "type"), typeIsFeedType(type) else {
				return false
			}
			guard let urlString = urlString(from: attributes), !urlString.isEmpty else {
				return false
			}

			return true
		}

		return feedLinkTags.isEmpty ? nil : feedLinkTags
	}

	static func typeIsFeedType(_ type: String) -> Bool {

		let lowerType = type.lowercased()
		return lowerType.hasSuffix("/rss+xml") || lowerType.hasSuffix("/atom+xml") || lowerType.hasSuffix("/json")
	}

	static func linkTags(_ tags: [HTMLTag]) -> [HTMLTag]? {

		let linkTags = tags.filter { $0.tagType == .link }
		return linkTags.isEmpty ? nil : linkTags
	}

	static func linkTagsWithMatchingRel(_ valueToMatch: String, _ tags: [HTMLTag]) -> [HTMLTag]? {

		// Case-insensitive; matches a whitespace-delimited word

		guard let linkTags = linkTags(tags) else {
			return nil
		}

		let tagsWithURLString = linkTags.filter { tag in
			guard let attributes = tag.attributes else {
				return false
			}
			guard let urlString = urlString(from: attributes), !urlString.isEmpty else {
				return false
			}
			return true
		}
		if tagsWithURLString.isEmpty {
			return nil
		}

		guard let matchingTags = tagsMatchingRelValues([valueToMatch], tagsWithURLString) else {
			return nil
		}
		return matchingTags.isEmpty ? nil : matchingTags
	}

	static func tagsMatchingRelValues(_ valuesToMatch: [String], _ tags: [HTMLTag]) -> [HTMLTag]? {

		let lowerValuesToMatch = valuesToMatch.map { $0.lowercased() }

		let matchingTags: [HTMLTag] = {

			tags.filter { tag in

				guard let attributes = tag.attributes else {
					return false
				}
				guard let relValue = relValue(from: attributes) else {
					return false
				}

				let relValues = relValue.components(separatedBy: .whitespacesAndNewlines)
				for oneRelValue in relValues {
					let oneLowerRelValue = oneRelValue.lowercased()

					for lowerValueToMatch in lowerValuesToMatch {
						if lowerValueToMatch == oneLowerRelValue {
							return true
						}
					}
				}

				return false
			}
		}()

		return matchingTags.isEmpty ? nil : matchingTags
	}
}

public final class HTMLMetadataAppleTouchIcon: Sendable {

	public let rel: String?
	public let sizes: String?
	public let size: CGSize?
	public let urlString: String? // Absolute

	init(_ urlString: String, _ tag: HTMLTag) {

		guard let attributes = tag.attributes else {
			self.rel = nil
			self.sizes = nil
			self.size = nil
			self.urlString = nil
			return
		}

		self.rel = attributes.object(forCaseInsensitiveKey: "rel")
		self.urlString = absoluteURLString(from: attributes, baseURL: urlString)

		guard let sizes = attributes.object(forCaseInsensitiveKey: "sizes") else {
			self.sizes = nil
			self.size = nil
			return
		}
		self.sizes = sizes

		let sizeComponents = sizes.components(separatedBy: CharacterSet(charactersIn: "x"))
		if sizeComponents.count == 2, let width = Double(sizeComponents[0]), let height = Double(sizeComponents[1]) {
			self.size = CGSize(width: width, height: height)
		}
		else {
			self.size = nil
		}
	}
}

public final class HTMLMetadataFeedLink: Sendable {

	public let title: String?
	public let type: String?
	public let urlString: String? // Absolute

	init(_ urlString: String, _ tag: HTMLTag) {

		guard let attributes = tag.attributes else {
			self.title = nil
			self.type = nil
			self.urlString = nil
			return
		}

		self.urlString = absoluteURLString(from: attributes, baseURL: urlString)
		self.title = attributes.object(forCaseInsensitiveKey: "title")
		self.type = attributes.object(forCaseInsensitiveKey: "type")
	}
}

public final class HTMLMetadataFavicon: Sendable {

	public let type: String?
	public let urlString: String?

	init(_ urlString: String, _ tag: HTMLTag) {

		guard let attributes = tag.attributes else {
			self.type = nil
			self.urlString = nil
			return
		}

		self.urlString = absoluteURLString(from: attributes, baseURL: urlString)
		self.type = attributes.object(forCaseInsensitiveKey: "type")
	}
}

public final class HTMLOpenGraphProperties: Sendable {

	// TODO: the rest. At this writing (Nov. 26, 2017) I just care about og:image.
	// See http://ogp.me/

	public let image: HTMLOpenGraphImage?

	init(_ urlString: String, _ tags: [HTMLTag]) {

		self.image = Self.parse(tags)
	}
}

private extension HTMLOpenGraphProperties {

	private static let ogPrefix = "og:"

	struct OGKey {
		static let property = "property"
		static let content = "content"
	}

	struct OGValue {
		static let ogImage = "og:image"
		static let ogImageURL = "og:image:url"
		static let ogImageSecureURL = "og:image:secure_url"
		static let ogImageType = "og:image:type"
		static let ogImageAlt = "og:image:alt"
		static let ogImageWidth = "og:image:width"
		static let ogImageHeight = "og:image:height"
	}

	static func parse(_ tags: [HTMLTag]) -> HTMLOpenGraphImage? {

		let metaTags = tags.filter { $0.tagType == .meta }
		if metaTags.isEmpty {
			return nil
		}

		// HTMLOpenGraphImage properties to fill in.
		var url: String?
		var secureURL: String?
		var mimeType: String?
		var width: CGFloat?
		var height: CGFloat?
		var altText: String?

		for tag in metaTags {

			guard let attributes = tag.attributes else {
				continue
			}
			guard let propertyName = attributes[OGKey.property], propertyName.hasPrefix(ogPrefix) else {
				continue
			}
			guard let content = attributes[OGKey.content] else {
				continue
			}

			if propertyName == OGValue.ogImage {
				url = content
			}
			else if propertyName == OGValue.ogImageURL {
				url = content
			}
			else if propertyName == OGValue.ogImageSecureURL {
				secureURL = content
			}
			else if propertyName == OGValue.ogImageType {
				mimeType = content
			}
			else if propertyName == OGValue.ogImageAlt {
				altText = content
			}
			else if propertyName == OGValue.ogImageWidth {
				if let value = Double(content) {
					width = CGFloat(value)
				}
			}
			else if propertyName == OGValue.ogImageHeight {
				if let value = Double(content) {
					height = CGFloat(value)
				}
			}
		}

		if url == nil && secureURL == nil && mimeType == nil && width == nil && height == nil && altText == nil {
			return nil
		}
		
		return HTMLOpenGraphImage(url: url, secureURL: secureURL, mimeType: mimeType, width: width, height: height, altText: altText)
	}
}

public final class HTMLOpenGraphImage: Sendable {

	public let url : String?
	public let secureURL: String?
	public let mimeType: String?
	public let width: CGFloat?
	public let height: CGFloat?
	public let altText: String?

	init(url: String?, secureURL: String?, mimeType: String?, width: CGFloat?, height: CGFloat?, altText: String?) {

		self.url = url
		self.secureURL = secureURL
		self.mimeType = mimeType
		self.width = width
		self.height = height
		self.altText = altText
	}
}

public final class HTMLTwitterProperties: Sendable {

	public let imageURL: String? // twitter:image:src

	private struct TwitterKey {
		static let name = "name"
		static let content = "content"
	}

	private struct TwitterValue {
		static let imageSrc = "twitter:image:src"
	}

	init(_ urlString: String, _ tags: [HTMLTag]) {

		let imageURL: String? = {
			for tag in tags {
				guard tag.tagType == .meta else {
					continue
				}
				guard let name = tag.attributes?[TwitterKey.name], name == TwitterValue.imageSrc else {
					continue
				}
				guard let content = tag.attributes?[TwitterKey.content], !content.isEmpty else {
					continue
				}
				return content
			}

			return nil
		}()

		self.imageURL = imageURL
	}
}

private func urlString(from attributes: HTMLTagAttributes) -> String? {

	if let urlString = attributes.object(forCaseInsensitiveKey: "href") {
		return urlString
	}
	return attributes.object(forCaseInsensitiveKey: "src")
}

private func relValue(from attributes: HTMLTagAttributes) -> String? {

	attributes.object(forCaseInsensitiveKey: "rel")
}

private func absoluteURLString(from attributes: HTMLTagAttributes, baseURL: String) -> String? {

	guard let urlString = urlString(from: attributes), !urlString.isEmpty else {
		return nil
	}

	return absoluteURLStringWithRelativeURLString(urlString, baseURLString: baseURL)
}

private func absoluteURLStringWithRelativeURLString(_ relativeURLString: String, baseURLString: String) -> String? {

	guard let baseURL = URL(string: baseURLString) else {
		return nil
	}
	guard let absoluteURL = URL(string: relativeURLString, relativeTo: baseURL) else {
		return nil
	}
	return absoluteURL.absoluteURL.standardized.absoluteString
}

