//
//  AtomParser.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation
#if SWIFT_PACKAGE
import RSParserObjC
#endif

// Pure-Swift Atom feed parser.
// Replaces the ObjC RSAtomParser. Uses the Swift XMLSAXParser and builds a
// ParsedFeed directly.

public struct AtomParser {

	public static func parse(_ parserData: ParserData) -> ParsedFeed? {
		let delegate = AtomDelegate(urlString: parserData.url)
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(parserData.data)
		return delegate.buildParsedFeed()
	}
}

// MARK: - Delegate

private final class AtomDelegate: XMLSAXParserDelegate {

	private let feedURLString: String
	private let dateParsed = Date()
	private let isDaringFireball: Bool

	// Feed-level accumulators
	private var feedTitle: String?
	private var homepageURLString: String?
	private var language: String?
	private var iconURLString: String?
	private var logoURLString: String?

	// Items + author
	private var items: [MutableAtomItem] = []
	private var rootAuthor: ParsedAuthor?
	private var currentAuthor: MutableAuthor?

	// Parse state
	private var parsingArticle = false
	private var parsingAuthor = false
	private var parsingSource = false
	private var endFeedFound = false

	// Attributes captured per-open-element (stack matches element stack).
	// Store the `XMLAttributes` value directly — it does targeted byte-level
	// lookups without building a dictionary, so we only pay for String
	// allocation on the attributes we actually read.
	private var attributesStack: [XMLAttributes] = []

	init(urlString: String) {
		self.feedURLString = urlString
		self.isDaringFireball = urlString.contains("daringfireball.net/")
	}

	// MARK: Building output

	func buildParsedFeed() -> ParsedFeed {
		// Apply root author to any items that have no authors.
		if let rootAuthor {
			for item in items where item.authors.isEmpty {
				item.authors.insert(rootAuthor)
			}
		}

		let iconURL = iconURLString ?? logoURLString
		let parsedItems = Set(items.map { $0.toParsedItem(feedURL: feedURLString, dateParsed: dateParsed) })

		return ParsedFeed(
			type: .atom,
			title: feedTitle,
			homePageURL: homepageURLString,
			feedURL: feedURLString,
			language: language,
			feedDescription: nil,
			nextURL: nil,
			iconURL: iconURL,
			faviconURL: nil,
			authors: nil,
			expired: false,
			hubs: nil,
			items: parsedItems
		)
	}

	private var currentArticle: MutableAtomItem? {
		items.last
	}

	private var currentAttributes: XMLAttributes {
		attributesStack.last ?? .empty
	}

	// MARK: Start

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didStartElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace,
	                  attributes: XMLAttributes) {
		if endFeedFound {
			return
		}

		attributesStack.append(attributes)

		if localName.equals("entry") {
			parsingArticle = true
			items.append(MutableAtomItem())
			return
		}

		if localName.equals("author") {
			parsingAuthor = true
			currentAuthor = MutableAuthor()
			return
		}

		if localName.equals("source") {
			parsingSource = true
			return
		}

		let isContentTag = localName.equals("content")
		let isSummaryTag = localName.equals("summary")
		if parsingArticle && (isContentTag || isSummaryTag) {
			if isContentTag {
				currentArticle?.language = currentAttributes["xml:lang"]
			}
			if currentAttributes["type"] == "xhtml" {
				// Hand off to the parser: we want the raw inner bytes, not a
				// reconstructed walk of the children.
				parser.captureRawInnerContent()
				return
			}
		}

		if !parsingArticle && localName.equals("link") {
			addHomePageLink()
			return
		}

		if localName.equals("feed") {
			language = currentAttributes["xml:lang"]
		}

		parser.beginStoringCharacters()
	}

	// MARK: Raw inner content (xhtml)

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didCaptureRawInnerContent bytes: ArraySlice<UInt8>,
	                  forElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace) {
		// Only `<content type="xhtml">` and `<summary type="xhtml">` request this.
		guard let article = currentArticle else {
			return
		}
		let html = String(decoding: bytes, as: UTF8.self)
		if localName.equals("content") {
			article.body = html
		} else if localName.equals("summary") {
			if article.body == nil || article.body?.isEmpty == true {
				article.body = html
			}
		}
	}

	// MARK: End

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didEndElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace) {
		defer {
			if !attributesStack.isEmpty {
				attributesStack.removeLast()
			}
		}

		if localName.equals("feed") {
			endFeedFound = true
			return
		}

		if endFeedFound {
			return
		}

		if parsingAuthor {
			handleAuthorElementEnd(parser: parser, localName: localName, namespace: namespace)
			return
		}

		if localName.equals("entry") {
			parsingArticle = false
			return
		}

		if parsingArticle && !parsingSource {
			handleArticleElementEnd(parser: parser, localName: localName, namespace: namespace)
			return
		}

		if localName.equals("source") {
			parsingSource = false
			return
		}

		if !parsingArticle && !parsingSource {
			handleFeedElementEnd(parser: parser, localName: localName, namespace: namespace)
		}
	}

	// MARK: - Article elements

	private func handleArticleElementEnd(parser: XMLSAXParser, localName: ArraySlice<UInt8>, namespace: XMLNamespace) {
		guard let article = currentArticle else {
			return
		}

		if namespace.prefix != nil {
			return // Prefixed article elements are handled via raw content capture for XHTML,
			       // and otherwise ignored.
		}

		if localName.equals("id") {
			article.guid = parser.currentStringWithTrimmedWhitespace
		} else if localName.equals("title") {
			article.title = parser.currentStringWithTrimmedWhitespace
		} else if localName.equals("content") {
			// Only overwrite if we actually accumulated characters — the xhtml path
			// sets `body` up-front via didCaptureRawInnerContent and doesn't store chars.
			if let s = parser.currentStringWithTrimmedWhitespace {
				article.body = s
			}
		} else if localName.equals("summary") {
			if article.body == nil {
				article.body = parser.currentStringWithTrimmedWhitespace
			}
		} else if localName.equals("link") {
			handleArticleLink()
		} else if localName.equals("published") {
			article.datePublished = dateFromParser(parser)
		} else if localName.equals("updated") {
			article.dateModified = dateFromParser(parser)
		} else if localName.equals("issued") {
			if article.datePublished == nil {
				article.datePublished = dateFromParser(parser)
			}
		} else if localName.equals("modified") {
			if article.dateModified == nil {
				article.dateModified = dateFromParser(parser)
			}
		}
	}

	private func handleArticleLink() {
		guard let article = currentArticle else {
			return
		}
		let attributes = currentAttributes
		guard let urlString = attributes["href"], !urlString.isEmpty else {
			return
		}
		guard let resolved = resolvedURLString(urlString) else {
			return
		}

		let rel = attributes["rel"] ?? "alternate"

		if rel == "enclosure" {
			let length = Int(attributes["length"] ?? "") ?? 0
			let sizeInBytes = length > 0 ? length : nil
			if let attachment = ParsedAttachment(url: resolved, mimeType: attributes["type"], title: attributes["title"], sizeInBytes: sizeInBytes, durationInSeconds: nil) {
				article.attachments.insert(attachment)
			}
			return
		}

		if isDaringFireball {
			let isDaringFireballLink = resolved.hasPrefix("https://daringfireball.net/")
			if isDaringFireballLink {
				if article.permalink == nil || article.permalink!.isEmpty {
					article.permalink = resolved
				}
			} else {
				if article.link == nil || article.link!.isEmpty {
					article.link = resolved
				}
			}
			return
		}

		if rel == "related" {
			if article.link == nil || article.link!.isEmpty {
				article.link = resolved
			}
		}
		if rel == "alternate" {
			if article.permalink == nil || article.permalink!.isEmpty {
				article.permalink = resolved
			}
		}
	}

	// MARK: - Author

	private func handleAuthorElementEnd(parser: XMLSAXParser, localName: ArraySlice<UInt8>, namespace: XMLNamespace) {
		if localName.equals("author") {
			parsingAuthor = false
			if let current = currentAuthor {
				let author = current.build()
				if parsingArticle {
					if let author {
						currentArticle?.authors.insert(author)
					}
				} else {
					if rootAuthor == nil, let author {
						rootAuthor = author
					}
				}
			}
			currentAuthor = nil
			return
		}
		guard let author = currentAuthor else {
			return
		}
		if localName.equals("name") {
			author.name = parser.currentStringWithTrimmedWhitespace
		} else if localName.equals("email") {
			author.emailAddress = parser.currentStringWithTrimmedWhitespace
		} else if localName.equals("uri") {
			author.url = parser.currentStringWithTrimmedWhitespace
		}
	}

	// MARK: - Feed elements

	private func handleFeedElementEnd(parser: XMLSAXParser, localName: ArraySlice<UInt8>, namespace: XMLNamespace) {
		if namespace.prefix != nil {
			return
		}
		if localName.equals("title") {
			if feedTitle == nil || feedTitle!.isEmpty {
				feedTitle = parser.currentStringWithTrimmedWhitespace
			}
		} else if localName.equals("icon") {
			if let s = parser.currentStringWithTrimmedWhitespace, !s.isEmpty {
				iconURLString = s
			}
		} else if localName.equals("logo") {
			if logoURLString == nil, let s = parser.currentStringWithTrimmedWhitespace, !s.isEmpty {
				logoURLString = s
			}
		}
	}

	private func addHomePageLink() {
		if let h = homepageURLString, !h.isEmpty {
			return
		}
		let attributes = currentAttributes
		guard let rawLink = attributes["href"], !rawLink.isEmpty else {
			return
		}
		let rel = attributes["rel"]
		// rel="alternate" or no rel (spec says "alternate" is default)
		if rel == nil || rel == "alternate" {
			homepageURLString = resolvedURLString(rawLink)
		}
	}

	private func dateFromParser(_ parser: XMLSAXParser) -> Date? {
		guard let bytes = parser.currentCharacters else {
			return nil
		}
		return DateParser.date(bytes: bytes[...])
	}

	// MARK: - URL resolution

	private func resolvedURLString(_ s: String) -> String? {
		if isValidURLString(s) {
			return s
		}
		var base: String? = homepageURLString
		if base?.isEmpty ?? true {
			base = feedURLString
		}
		guard let baseString = base, !baseString.isEmpty,
		      let baseURL = URL(string: baseString) else {
			return nil
		}
		guard let resolved = URL(string: s, relativeTo: baseURL) else {
			return nil
		}
		let urlString = resolved.absoluteString
		if !urlString.isEmpty && isValidURLString(urlString) {
			return urlString
		}
		return nil
	}

	private func isValidURLString(_ s: String) -> Bool {
		let lower = s.lowercased()
		return lower.hasPrefix("http://") || lower.hasPrefix("https://")
	}
}

// MARK: - MutableAtomItem

private final class MutableAtomItem {
	var guid: String?
	var title: String?
	var body: String?
	var link: String?
	var permalink: String?
	var language: String?
	var datePublished: Date?
	var dateModified: Date?
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
			markdown: nil,
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
		let dpString: String?
		if let datePublished {
			dpString = String(format: "%.0f", datePublished.timeIntervalSince1970)
		} else {
			dpString = nil
		}
		var s = ""
		if let permalink, !permalink.isEmpty, let dpString {
			s = permalink + dpString
		} else if let link, !link.isEmpty, let dpString {
			s = link + dpString
		} else if let title, !title.isEmpty, let dpString {
			s = title + dpString
		} else if let dpString {
			s = dpString
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

private final class MutableAuthor {
	var name: String?
	var emailAddress: String?
	var url: String?

	func build() -> ParsedAuthor? {
		if name == nil && emailAddress == nil && url == nil {
			return nil
		}
		return ParsedAuthor(name: name, url: url, avatarURL: nil, emailAddress: emailAddress)
	}
}

