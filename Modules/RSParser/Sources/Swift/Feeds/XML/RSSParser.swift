//
//  RSSParser.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation
#if SWIFT_PACKAGE
import RSParserObjC
#endif

// Pure-Swift RSS/RDF feed parser.
// Replaces the ObjC RSRSSParser. Uses the Swift XMLSAXParser and emits a
// ParsedFeed directly — no RSParsedFeed intermediate.

public struct RSSParser {

	public static func parse(_ parserData: ParserData) -> ParsedFeed? {
		let delegate = RSSDelegate(urlString: parserData.url)
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(parserData.data)
		return delegate.buildParsedFeed()
	}
}

// MARK: - Delegate

private final class RSSDelegate: XMLSAXParserDelegate {

	private let feedURLString: String
	private let dateParsed = Date()

	// Feed-level state
	private var title: String?
	private var homepageURLString: String?
	private var language: String?
	private var channelImageURLString: String?
	private var isRDF = false
	private var endRSSFound = false

	// Article parsing state
	private var items: [MutableItem] = []
	private var parsingArticle = false
	private var parsingAuthor = false
	private var parsingChannelImage = false
	private var currentAttributes: [String: String] = [:]

	init(urlString: String) {
		self.feedURLString = urlString
	}

	// MARK: Building output

	func buildParsedFeed() -> ParsedFeed {
		let parsedItems = Set(items.map { $0.toParsedItem(feedURL: feedURLString, dateParsed: dateParsed) })
		return ParsedFeed(
			type: .rss,
			title: title,
			homePageURL: homepageURLString,
			feedURL: feedURLString,
			language: language,
			feedDescription: nil,
			nextURL: nil,
			iconURL: channelImageURLString,
			faviconURL: nil,
			authors: nil,
			expired: false,
			hubs: nil,
			items: parsedItems
		)
	}

	private var currentItem: MutableItem? {
		items.last
	}

	// MARK: Start

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didStartElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace,
	                  attributes: XMLAttributes) {
		if endRSSFound {
			return
		}

		let isUnprefixed = namespace.prefix == nil

		// RDF root
		if isUnprefixed && localName.equals("RDF") {
			isRDF = true
			return
		}

		// Grab attributes where we'll need them later.
		if (isRDF && localName.equals("item"))
			|| localName.equals("guid")
			|| localName.equals("enclosure") {
			currentAttributes = attributes.dictionary()
		} else {
			currentAttributes = [:]
		}

		if isUnprefixed && localName.equals("item") {
			items.append(MutableItem())
			parsingArticle = true

			if isRDF, let about = currentAttributes["rdf:about"], !about.isEmpty {
				currentItem?.guid = about
				currentItem?.permalink = about
			}
		} else if isUnprefixed && localName.equals("image") {
			parsingChannelImage = true
		} else if isUnprefixed && localName.equals("author") {
			if parsingArticle {
				parsingAuthor = true
			}
		}

		if !parsingChannelImage {
			parser.beginStoringCharacters()
		} else if isUnprefixed && localName.equals("url") {
			parser.beginStoringCharacters()
		}
	}

	// MARK: End

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didEndElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace) {
		if endRSSFound {
			return
		}

		let isUnprefixed = namespace.prefix == nil

		if isRDF && isUnprefixed && localName.equals("RDF") {
			endRSSFound = true
			return
		}

		if isUnprefixed && localName.equals("rss") {
			endRSSFound = true
			return
		}

		if parsingChannelImage && !parsingArticle && isUnprefixed && localName.equals("url") {
			channelImageURLString = trimmedCurrentString(parser: parser)
			return
		}

		if isUnprefixed && localName.equals("image") {
			parsingChannelImage = false
			return
		}

		if isUnprefixed && localName.equals("item") {
			parsingArticle = false
			return
		}

		if parsingArticle {
			handleArticleElementEnd(parser: parser, localName: localName, namespace: namespace)
			if isUnprefixed && localName.equals("author") {
				parsingAuthor = false
			}
			return
		}

		if !parsingChannelImage {
			handleFeedElementEnd(parser: parser, localName: localName, namespace: namespace)
		}
	}

	// MARK: Article elements

	private func handleArticleElementEnd(parser: XMLSAXParser, localName: ArraySlice<UInt8>, namespace: XMLNamespace) {
		guard let article = currentItem else {
			return
		}

		// Prefixed elements: Dublin Core, content:encoded, source:markdown.
		if namespace.prefix != nil {
			if namespace.isDublinCore {
				if localName.equals("creator") {
					addAuthor(toArticle: article, string: trimmedCurrentString(parser: parser))
				} else if localName.equals("date") {
					if let s = parser.currentCharacters {
						article.datePublished = DateParser.date(bytes: s[...])
					}
				}
				return
			}
			if namespace.isContent && localName.equals("encoded") {
				let s = trimmedCurrentString(parser: parser)
				if let s, !s.isEmpty {
					article.body = s
				}
				return
			}
			// `source:markdown` — scripting.com's namespace, used by WordLand-generated feeds.
			if namespace.isSource && localName.equals("markdown") {
				article.markdown = trimmedCurrentString(parser: parser)
				return
			}
			return
		}

		if localName.equals("guid") {
			handleGuid(article: article, parser: parser)
		} else if localName.equals("pubDate") {
			if let bytes = parser.currentCharacters {
				article.datePublished = DateParser.date(bytes: bytes[...])
			}
		} else if localName.equals("author") {
			addAuthor(toArticle: article, string: trimmedCurrentString(parser: parser))
		} else if localName.equals("link") {
			if article.link == nil {
				if let s = trimmedCurrentString(parser: parser), !s.isEmpty {
					article.link = resolveURL(s)
				}
			}
		} else if localName.equals("description") {
			if article.body == nil {
				article.body = trimmedCurrentString(parser: parser)
			}
		} else if !parsingAuthor && localName.equals("title") {
			if let s = trimmedCurrentString(parser: parser) {
				article.title = s
			}
		} else if localName.equals("enclosure") {
			handleEnclosure(article: article)
		}
	}

	private func handleGuid(article: MutableItem, parser: XMLSAXParser) {
		guard let guid = trimmedCurrentString(parser: parser) else {
			return
		}
		article.guid = guid

		let isPermaLinkValue = objectForCaseInsensitiveKey(currentAttributes, "ispermalink")
		if isPermaLinkValue == nil || isPermaLinkValue?.lowercased() != "false" {
			if stringIsProbablyURLOrRelativePath(guid) {
				article.permalink = resolveURL(guid)
			}
		}
	}

	private func handleEnclosure(article: MutableItem) {
		guard let url = currentAttributes["url"], !url.isEmpty else {
			return
		}
		let length = Int(currentAttributes["length"] ?? "") ?? 0
		let mimeType = currentAttributes["type"]
		let sizeInBytes = length > 0 ? length : nil
		if let attachment = ParsedAttachment(url: url, mimeType: mimeType, title: nil, sizeInBytes: sizeInBytes, durationInSeconds: nil) {
			article.attachments.insert(attachment)
		}
	}

	// MARK: Channel / feed elements

	private func handleFeedElementEnd(parser: XMLSAXParser, localName: ArraySlice<UInt8>, namespace: XMLNamespace) {
		if namespace.prefix != nil {
			return
		}

		if localName.equals("link") {
			if homepageURLString == nil || homepageURLString!.isEmpty {
				homepageURLString = trimmedCurrentString(parser: parser)
			}
		} else if localName.equals("title") {
			title = trimmedCurrentString(parser: parser)
		} else if localName.equals("language") {
			language = trimmedCurrentString(parser: parser)
		}
	}

	// MARK: Helpers

	private func trimmedCurrentString(parser: XMLSAXParser) -> String? {
		parser.currentStringWithTrimmedWhitespace
	}

	private func addAuthor(toArticle article: MutableItem, string: String?) {
		guard let s = string, !s.isEmpty else {
			return
		}
		let author = authorFromSingleString(s)
		article.authors.insert(author)
	}

	/// RSS authors are supposed to be email addresses but often aren't. Classify by content.
	private func authorFromSingleString(_ s: String) -> ParsedAuthor {
		if s.contains("@") {
			return ParsedAuthor(name: nil, url: nil, avatarURL: nil, emailAddress: s)
		}
		if s.lowercased().hasPrefix("http") {
			return ParsedAuthor(name: nil, url: s, avatarURL: nil, emailAddress: nil)
		}
		return ParsedAuthor(name: s, url: nil, avatarURL: nil, emailAddress: nil)
	}

	private func stringIsProbablyURLOrRelativePath(_ s: String) -> Bool {
		// Based on RSRSSParser.m. Bad guids are often integers; also guids starting with "tag:" aren't URLs.
		if s.contains(" ") {
			return false
		}
		if !s.contains("/") {
			return false
		}
		if s.lowercased().hasPrefix("tag:") {
			return false
		}
		return true
	}

	private func resolveURL(_ s: String) -> String {
		if s.lowercased().hasPrefix("http") {
			return s
		}
		guard let baseString = homepageURLString, !baseString.isEmpty,
		      let baseURL = URL(string: baseString) else {
			return s
		}
		guard let resolved = URL(string: s, relativeTo: baseURL) else {
			return s
		}
		return resolved.absoluteString
	}

	private func objectForCaseInsensitiveKey(_ dict: [String: String], _ key: String) -> String? {
		if let v = dict[key] {
			return v
		}
		let target = key.lowercased()
		for (k, v) in dict where k.lowercased() == target {
			return v
		}
		return nil
	}
}

// MARK: - MutableItem

/// Internal mutable accumulator for one RSS item. Produces a ParsedItem at the end.
private final class MutableItem {
	var guid: String?
	var title: String?
	var body: String?
	var markdown: String?
	var link: String?          // External link
	var permalink: String?     // The URL associated with this item
	var datePublished: Date?
	var dateModified: Date?
	var language: String?
	var authors: Set<ParsedAuthor> = []
	var attachments: Set<ParsedAttachment> = []

	func toParsedItem(feedURL: String, dateParsed: Date) -> ParsedItem {
		return ParsedItem(
			syncServiceID: nil,
			uniqueID: calculatedUniqueID(),
			feedURL: feedURL,
			url: permalink,
			externalURL: link,
			title: title,
			language: language,
			contentHTML: body,
			contentText: nil,
			markdown: markdown,
			summary: nil,
			imageURL: nil,
			bannerImageURL: nil,
			datePublished: datePublished,
			dateModified: dateModified,
			authors: authors.isEmpty ? nil : authors,
			tags: nil,
			attachments: attachments.isEmpty ? nil : attachments
		)
	}

	private func calculatedUniqueID() -> String {
		if let guid, !guid.isEmpty {
			return guid
		}
		// Match the old RSParsedArticle.calculatedArticleID logic: concatenate something
		// useful then MD5. Preferred order: permalink+date, link+date, title+date, date alone,
		// permalink, link, title, body.
		var s = ""
		let datePublishedString: String?
		if let datePublished {
			datePublishedString = String(format: "%.0f", datePublished.timeIntervalSince1970)
		} else {
			datePublishedString = nil
		}

		if let permalink, !permalink.isEmpty, let datePublishedString {
			s = permalink + datePublishedString
		} else if let link, !link.isEmpty, let datePublishedString {
			s = link + datePublishedString
		} else if let title, !title.isEmpty, let datePublishedString {
			s = title + datePublishedString
		} else if let datePublishedString {
			s = datePublishedString
		} else if let permalink, !permalink.isEmpty {
			s = permalink
		} else if let link, !link.isEmpty {
			s = link
		} else if let title, !title.isEmpty {
			s = title
		} else if let body, !body.isEmpty {
			s = body
		}
		return s.md5String
	}
}
