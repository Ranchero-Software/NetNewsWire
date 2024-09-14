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

	private var parsingArticle = false
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
	}

	func addArticle() {
		let article = RSSArticle(feedURL)
		articles.append(article)
	}

	func addXHTMLTag(_ localName: XMLPointer) {

		guard var xhtmlString else {
			assertionFailure("xhtmlString must not be nil when in addXHTMLTag.")
			return
		}

		let name: String? = {
			let data = Data(bytes: localName, count: strlen(localName))
			return String(data: data, encoding: .utf8)
		}()
		guard let name else {
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

	}

	public func saxParser(_ saxParser: SAXParser, xmlEndElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?) {

	}

	public func saxParser(_ saxParser: SAXParser, xmlCharactersFound: XMLPointer, count: Int) {

		// Required method.
	}
}

