//
//  AtomParser.swift
//  Parser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

final class AtomParser {

	private var feedURL: String
	private let data: Data
	private let feed: RSSFeed

	private var articles = [RSSArticle]()
	private var currentArticle: RSSArticle? {
		articles.last
	}

	private var attributesStack = [StringDictionary]()
	private var currentAttributes: StringDictionary? {
		attributesStack.last
	}

	private var xmlBaseURL: URL?
	private var parsingXHTML = false
	private var xhtmlString: String?

	private var currentAuthor: RSSAuthor?
	private var parsingAuthor = false

	private var parsingArticle = false
	private var parsingSource = false
	private var endFeedFound = false

	private var depth = 0
	private var entryDepth = -1

	static func parsedFeed(urlString: String, data: Data) -> RSSFeed {

		let parser = AtomParser(urlString: urlString, data: data)
		parser.parse()
		return parser.feed
	}

	init(urlString: String, data: Data) {
		self.feedURL = urlString
		self.data = data
		self.feed = RSSFeed(urlString: urlString)
	}
}

private extension AtomParser {

	func parse() {

		let saxParser = SAXParser(delegate: self, data: data)
		saxParser.parse()
		feed.articles = articles
	}

	private struct XMLName {
		static let entry = "entry".utf8CString
		static let content = "content".utf8CString
		static let summary = "summary".utf8CString
		static let link = "link".utf8CString
		static let feed = "feed".utf8CString
		static let source = "source".utf8CString
		static let author = "author".utf8CString
		static let name = "name".utf8CString
		static let email = "email".utf8CString
		static let uri = "uri".utf8CString
		static let title = "title".utf8CString
		static let id = "id".utf8CString
		static let published = "published".utf8CString
		static let updated = "updated".utf8CString
		static let issued = "issued".utf8CString
		static let modified = "modified".utf8CString
	}

	private struct AttributeKey {
		static let rel = "rel"
		static let href = "href"
		static let title = "title"
		static let type = "type"
		static let length = "length"
		static let xmlLang = "xml:lang"
		static let xmlBase = "xml:base"
	}

	private struct AttributeValue {
		static let text = "text"
		static let alternate = "alternate"
		static let related = "related"
		static let enclosure = "enclosure"
	}

	func currentString(_ saxParser: SAXParser) -> String? {

		saxParser.currentStringWithTrimmedWhitespace
	}

	func currentDate(_ saxParser: SAXParser) -> Date? {

		guard let data = saxParser.currentCharacters else {
			assertionFailure("Unexpected nil saxParser.currentCharacters in AtomParser.currentDate")
			return nil
		}

		return DateParser.date(data: data)
	}

	func addFeedTitle(_ saxParser: SAXParser) {

		guard feed.title == nil else {
			return
		}

		if let title = currentString(saxParser), !title.isEmpty {
			feed.title = title
		}
	}

	func addFeedLink() {

		guard feed.link == nil, let currentAttributes else {
			return
		}
		guard let link = currentAttributes[AttributeKey.href] else {
			return
		}

		let isRelated: Bool = {
			if let related = currentAttributes[AttributeKey.rel], related == AttributeValue.alternate { // rel="alternate"
				return true
			}
			return currentAttributes.count == 1 // Example: <link href="https://www.allenpike.com/"/> — no rel or anything
		}()

		if isRelated {
			feed.link = link
		}
	}

	func addFeedAttributes() {

		guard let currentAttributes else {
			return
		}

		if feed.language == nil {
			feed.language = currentAttributes[AttributeKey.xmlLang]
		}

		if xmlBaseURL == nil {
			if let xmlBase = currentAttributes[AttributeKey.xmlBase] {
				if let baseURL = URL(string: xmlBase) {
					xmlBaseURL = baseURL
				}
			}
		}
	}

	func addArticle() {
		let article = RSSArticle(feedURL)
		articles.append(article)
	}

	func addArticleElement(_ saxParser: SAXParser, _ localName: XMLPointer, _ prefix: XMLPointer?) {

		guard prefix == nil else {
			return
		}
		guard let currentArticle else {
			assertionFailure("currentArticle must not be nil in AtomParser.addArticleElement")
			return
		}

		if SAXEqualTags(localName, XMLName.id) {
			currentArticle.guid = currentString(saxParser)
		}

		else if SAXEqualTags(localName, XMLName.title) {
			currentArticle.title = currentString(saxParser)
		}

		else if SAXEqualTags(localName, XMLName.content) {
			addContent(saxParser, currentArticle)
		}

		else if SAXEqualTags(localName, XMLName.summary) {
			addSummary(saxParser, currentArticle)
		}

		else if SAXEqualTags(localName, XMLName.link) {
			addLink(currentArticle)
		}

		else if SAXEqualTags(localName, XMLName.published) {
			currentArticle.datePublished = currentDate(saxParser)
		}

		else if SAXEqualTags(localName, XMLName.updated) {
			currentArticle.dateModified = currentDate(saxParser)
		}

		// Atom 0.3 dates
		else if SAXEqualTags(localName, XMLName.issued) {
			if currentArticle.datePublished == nil {
				currentArticle.datePublished = currentDate(saxParser)
			}
		}
		else if SAXEqualTags(localName, XMLName.modified) {
			if currentArticle.dateModified == nil {
				currentArticle.dateModified = currentDate(saxParser)
			}
		}
	}

	func addContent(_ saxParser: SAXParser, _ article: RSSArticle) {

		var content = currentString(saxParser)

		if currentAttributes?[AttributeKey.type] == AttributeValue.text {
			content = content?.replacingOccurrences(of: "\n", with: "\n<br>")
		}

		article.body = content
	}

	func addSummary(_ saxParser: SAXParser, _ article: RSSArticle) {

		guard article.body == nil else {
			return
		}
		article.body = currentString(saxParser)
	}

	func addLink(_ article: RSSArticle) {

		guard let attributes = currentAttributes else {
			return
		}
		guard let urlString = attributes[AttributeKey.href], !urlString.isEmpty else {
			return
		}
		let resolvedURLString = linkResolvedAgainstXMLBase(urlString)

		var rel = attributes[AttributeKey.rel]
		if rel?.isEmpty ?? true {
			rel = AttributeValue.alternate
		}

		if rel == AttributeValue.related {
			if article.link == nil {
				article.link = resolvedURLString
			}
		}
		else if rel == AttributeValue.alternate {
			if article.permalink == nil {
				article.permalink = resolvedURLString
			}
		}
		else if rel == AttributeValue.enclosure {
			if let enclosure = enclosure(resolvedURLString, attributes) {
				article.addEnclosure(enclosure)
			}
		}
	}

	func linkResolvedAgainstXMLBase(_ urlString: String) -> String {

		guard let xmlBaseURL else {
			return urlString
		}

		if let resolvedURL = URL(string: urlString, relativeTo: xmlBaseURL) {
			return resolvedURL.absoluteString
		}
		return urlString
	}

	func enclosure(_ urlString: String, _ attributes: StringDictionary) -> RSSEnclosure? {

		let enclosure = RSSEnclosure(url: urlString)
		enclosure.title = attributes[AttributeKey.title]
		enclosure.mimeType = attributes[AttributeKey.type]

		if let lengthString = attributes[AttributeKey.length] {
			enclosure.length = Int(lengthString)
		}

		return enclosure
	}

	func addXHTMLTag(_ localName: XMLPointer) {

		guard var xhtmlString else {
			assertionFailure("xhtmlString must not be nil when in addXHTMLTag.")
			return
		}

		guard let name = String(xmlPointer: localName) else {
			assertionFailure("Unexpected failure converting XMLPointer to String in addXHTMLTag.")
			return
		}

		xhtmlString.append("<")
		xhtmlString.append(name)

		if let currentAttributes, currentAttributes.count > 0 {
			for (key, value) in currentAttributes {
				xhtmlString.append(" ")
				xhtmlString.append(key)
				xhtmlString.append("=\"")

				let encodedValue = value.replacingOccurrences(of: "\"", with: "&quot;")
				xhtmlString.append(encodedValue)
				xhtmlString.append("\"")
			}
		}

		xhtmlString.append(">")
	}
}

extension AtomParser: SAXParserDelegate {

	public func saxParser(_ saxParser: SAXParser, xmlStartElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?, namespaceCount: Int, namespaces: UnsafePointer<XMLPointer?>?, attributeCount: Int, attributesDefaultedCount: Int, attributes: UnsafePointer<XMLPointer?>?) {

		depth += 1

		if endFeedFound {
			return
		}

		let xmlAttributes = saxParser.attributesDictionary(attributes, attributeCount: attributeCount) ?? StringDictionary()
		attributesStack.append(xmlAttributes)

		if parsingXHTML {
			addXHTMLTag(localName)
			return
		}

		if SAXEqualTags(localName, XMLName.entry) {
			parsingArticle = true
			entryDepth = depth
			addArticle()
			return
		}

		if SAXEqualTags(localName, XMLName.author) {
			parsingAuthor = true
			currentAuthor = RSSAuthor()
			return
		}

		if SAXEqualTags(localName, XMLName.source) {
			parsingSource = true
			return
		}

		let isContentTag = SAXEqualTags(localName, XMLName.content)
		let isSummaryTag = SAXEqualTags(localName, XMLName.summary)

		if parsingArticle && (isContentTag || isSummaryTag) {

			if isContentTag {
				currentArticle?.language = xmlAttributes["xml:lang"]
			}

			let contentType = xmlAttributes["type"];
			if contentType == "xhtml" {
				parsingXHTML = true
				xhtmlString = ""
				return
			}
		}

		if !parsingArticle && SAXEqualTags(localName, XMLName.link) {
			addFeedLink()
			return
		}

		if SAXEqualTags(localName, XMLName.feed) {
			addFeedAttributes()
		}

		saxParser.beginStoringCharacters()
	}

	public func saxParser(_ saxParser: SAXParser, xmlEndElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?) {

		defer {
			depth -= 1
		}

		if SAXEqualTags(localName, XMLName.feed) {
			endFeedFound = true
			return
		}

		if endFeedFound {
			return
		}

		if parsingXHTML {

			let isContentTag = SAXEqualTags(localName, XMLName.content)
			let isSummaryTag = SAXEqualTags(localName, XMLName.summary)

			if parsingArticle && (isContentTag || isSummaryTag) {

				if isContentTag {
					currentArticle?.body = xhtmlString
				}

				else if isSummaryTag {
					if (currentArticle?.body?.count ?? 0) < 1 {
						currentArticle?.body = xhtmlString
					}
				}
			}

			if isContentTag || isSummaryTag {
				parsingXHTML = false
			}

			if var xhtmlString {
				if let localNameString = String(xmlPointer: localName) {
					xhtmlString.append("</")
					xhtmlString.append(localNameString)
					xhtmlString.append(">")
				}
			} else {
				assertionFailure("xhtmlString must not be nil when parsingXHTML in xmlEndElement.")
			}
		}

		else if parsingAuthor {

			if SAXEqualTags(localName, XMLName.author) {
				parsingAuthor = false
				if let currentAuthor, !currentAuthor.isEmpty() {
					currentArticle?.addAuthor(currentAuthor)
				}
				currentAuthor = nil
			}
			else if SAXEqualTags(localName, XMLName.name) {
				currentAuthor?.name = saxParser.currentStringWithTrimmedWhitespace
			}
			else if SAXEqualTags(localName, XMLName.email) {
				currentAuthor?.emailAddress = saxParser.currentStringWithTrimmedWhitespace
			}
			else if SAXEqualTags(localName, XMLName.uri) {
				currentAuthor?.url = saxParser.currentStringWithTrimmedWhitespace
			}
		}

		else if SAXEqualTags(localName, XMLName.entry) {
			parsingArticle = false
			entryDepth = -1
		}

		else if parsingArticle && !parsingSource && depth == entryDepth + 1 {
			addArticleElement(saxParser, localName, prefix)
		}

		else if SAXEqualTags(localName, XMLName.source) {
			parsingSource = false
		}

		else if !parsingArticle && !parsingSource && SAXEqualTags(localName, XMLName.title) {
			addFeedTitle(saxParser)
		}

		_ = attributesStack.popLast()
	}

	public func saxParser(_ saxParser: SAXParser, xmlCharactersFound: XMLPointer, count: Int) {

		guard parsingXHTML else {
			return
		}
		guard var s = String(xmlPointer: xmlCharactersFound, count: count) else {
			return
		}

		// libxml decodes all entities; we need to re-encode certain characters
		// (<, >, and &) when inside XHTML text content.
		s = s.replacingOccurrences(of: "<", with: "&;lt;")
		s = s.replacingOccurrences(of: ">", with: "&;gt;")
		s = s.replacingOccurrences(of: "&", with: "&amp;")

		xhtmlString = s
	}
}
