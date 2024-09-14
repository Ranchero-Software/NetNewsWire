//
//  AtomParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import SAX
import DateParser

final class AtomParser {

	private var parserData: ParserData
	private var feedURL: String {
		parserData.url
	}
	private var data: Data {
		parserData.data
	}

	private let feed: RSSFeed

	private var articles = [RSSArticle]()
	private var currentArticle: RSSArticle? {
		articles.last
	}

	private var attributesStack = [SAXParser.XMLAttributesDictionary]()
	private var currentAttributes: SAXParser.XMLAttributesDictionary? {
		attributesStack.last
	}

	private var parsingXHTML = false
	private var xhtmlString: String?

	private var currentAuthor: RSSAuthor?
	private var parsingAuthor = false

	private var parsingArticle = false
	private var parsingSource = false
	private var endFeedFound = false

	static func parsedFeed(with parserData: ParserData) -> RSSFeed {

		let parser = AtomParser(parserData)
		parser.parse()
		return parser.feed
	}

	init(_ parserData: ParserData) {
		self.parserData = parserData
		self.feed = RSSFeed(urlString: parserData.url)
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
	}

	func addFeedTitle() {

	}

	func addFeedLink() {

	}

	func addFeedLanguage() {

	}

	func addArticle() {
		let article = RSSArticle(feedURL)
		articles.append(article)
	}

	func addArticleElement(_ localName: XMLPointer, _ prefix: XMLPointer?) {

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

		if endFeedFound {
			return
		}

		let xmlAttributes = saxParser.attributesDictionary(attributes, attributeCount: attributeCount) ?? SAXParser.XMLAttributesDictionary()
		attributesStack.append(xmlAttributes)

		if parsingXHTML {
			addXHTMLTag(localName)
			return
		}

		if SAXEqualTags(localName, XMLName.entry) {
			parsingArticle = true
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
			addFeedLanguage()
		}

		saxParser.beginStoringCharacters()
	}

	public func saxParser(_ saxParser: SAXParser, xmlEndElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?) {

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
		}

		else if parsingArticle && !parsingSource {
			addArticleElement(localName, prefix)
		}

		else if SAXEqualTags(localName, XMLName.source) {
			parsingSource = false
		}

		else if !parsingArticle && !parsingSource && SAXEqualTags(localName, XMLName.title) {
			addFeedTitle()
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

