//
//  RSSParser.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation

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
		let parsedItems = Set(items.map { $0.toParsedItem(feedURL: feedURLString) })
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

		// RDF root. The element is always prefixed in practice (`<rdf:RDF>`), so
		// the check ignores prefix — only the local name matters. Matches the
		// old ObjC parser's behavior; the earlier Swift version's `isUnprefixed`
		// guard here silently broke RSS 1.0 feeds (all items got calculated
		// uniqueIDs instead of their `rdf:about` URLs).
		if localName.equals("RDF") {
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

		if isRDF && localName.equals("RDF") {
			endRSSFound = true
			return
		}

		if isUnprefixed && localName.equals("rss") {
			endRSSFound = true
			return
		}

		if parsingChannelImage && !parsingArticle && isUnprefixed && localName.equals("url") {
			channelImageURLString = parser.currentStringWithTrimmedWhitespace
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
					addAuthor(toArticle: article, string: parser.currentStringWithTrimmedWhitespace)
				} else if localName.equals("date") {
					if let s = parser.currentCharacters {
						article.datePublished = DateParser.date(bytes: s[...])
					}
				}
				return
			}
			if namespace.isContent && localName.equals("encoded") {
				let s = parser.currentStringWithTrimmedWhitespace
				if let s, !s.isEmpty {
					article.body = s
				}
				return
			}
			// `source:markdown` — scripting.com's namespace, used by WordLand-generated feeds.
			if namespace.isSource && localName.equals("markdown") {
				article.markdown = parser.currentStringWithTrimmedWhitespace
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
			addAuthor(toArticle: article, string: parser.currentStringWithTrimmedWhitespace)
		} else if localName.equals("link") {
			if article.link == nil {
				if let s = parser.currentStringWithTrimmedWhitespace, !s.isEmpty {
					article.link = resolveURL(s)
				}
			}
		} else if localName.equals("description") {
			if article.body == nil {
				article.body = parser.currentStringWithTrimmedWhitespace
			}
		} else if !parsingAuthor && localName.equals("title") {
			if let s = parser.currentStringWithTrimmedWhitespace {
				article.title = s
			}
		} else if localName.equals("enclosure") {
			handleEnclosure(article: article)
		}
	}

	private func handleGuid(article: MutableItem, parser: XMLSAXParser) {
		guard let guid = parser.currentStringWithTrimmedWhitespace else {
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
				homepageURLString = parser.currentStringWithTrimmedWhitespace
			}
		} else if localName.equals("title") {
			title = parser.currentStringWithTrimmedWhitespace
		} else if localName.equals("language") {
			language = parser.currentStringWithTrimmedWhitespace
		}
	}

	// MARK: Helpers

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

