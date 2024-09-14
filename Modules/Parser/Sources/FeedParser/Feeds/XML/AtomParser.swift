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

	private var parsingArticle = false
	private var parsingXHTML = false
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

	func addArticle() {
		let article = RSSArticle(feedURL)
		articles.append(article)
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
//			addXHTMLTag(localName)
			return
		}

//		if SAXEqualTags(localName, "entry") {
//			parsingArticle = true
//			addArticle()
//			return
//		}

	}

	public func saxParser(_ saxParser: SAXParser, xmlEndElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?) {

	}

	public func saxParser(_ saxParser: SAXParser, xmlCharactersFound: XMLPointer, count: Int) {

		// Required method.
	}
}

