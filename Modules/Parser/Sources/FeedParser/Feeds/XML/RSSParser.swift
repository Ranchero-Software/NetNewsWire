//
//  RSSParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import SAX

public final class RSSParser {

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

	private var endRSSFound = false
	private var isRDF = false
	private var parsingArticle = false
	private var parsingChannelImage = false
	private var parsingAuthor = false
	private var currentAttributes: XMLAttributesDictionary?

	public static func parsedFeed(with parserData: ParserData) -> RSSFeed {

		let parser = RSSParser(parserData)
		parser.parse()
		return parser.feed
	}

	init(_ parserData: ParserData) {
		self.parserData = parserData
		self.feed = RSSFeed(urlString: parserData.url)
	}
}

private extension RSSParser {

	private struct XMLName {
		static let uppercaseRDF = "RDF".utf8CString
		static let item = "item".utf8CString
		static let guid = "guid".utf8CString
		static let enclosure = "enclosure".utf8CString
		static let rdfAbout = "rdf:about".utf8CString
		static let image = "image".utf8CString
		static let author = "author".utf8CString
		static let rss = "rss".utf8CString
		static let link = "link".utf8CString
		static let title = "title".utf8CString
		static let language = "language".utf8CString
		static let dc = "dc".utf8CString
		static let content = "content".utf8CString
		static let encoded = "encoded".utf8CString
	}

	func addFeedElement(_ localName: XMLPointer, _ prefix: XMLPointer?) {

		guard prefix == nil else {
			return
		}

		if SAXEqualTags(localName, XMLName.link) {
			if feed.link == nil {
				feed.link = currentString
			}
		}
		else if SAXEqualTags(localName, XMLName.title) {
			feed.title = currentString
		}
		else if SAXEqualTags(localName, XMLName.language) {
			feed.language = currentString
		}
	}

	func addArticle() {
		let article = RSSArticle(feedURL)
		articles.append(article)
	}

	func addArticleElement(_ localName: XMLPointer, _ prefix: XMLPointer?) {
		
		if SAXEqualTags(prefix, XMLName.dc) {
			addDCElement(localName)
			return;
		}

		if SAXEqualTags(prefix, XMLName.content) && SAXEqualTags(localName, XMLName.encoded) {
			if let currentString, !currentString.isEmpty {
				currentArticle.body = currentString
			}
			return
		}

		guard prefix == nil else {
			return
		}

		if SAXEqualTags(localName, XMLName.guid) {
			addGuid()
		}
		else if SAXEqualTags(localName, XMLName.pubDate) {
			currentArticle.datePublished = currentDate
		}
		else if SAXEqualTags(localName, XMLName.author) {
			addAuthorWithString(currentString)
		}
		else if SAXEqualTags(localName, XMLName.link) {
			currentArticle.link = urlString(currentString)
		}
		else if SAXEqualTags(localName, XMLName.description) {
			if currentArticle.body == nil {
				currentArticle.body = currentString
			}
		}
		else if !parsingAuthor && SAXEqualTags(localName, XMLName.title) {
			if let currentString {
				currentArticle.title = currentString
			}
		}
		else if SAXEqualTags(localName, XMLName.enclosure) {
			addEnclosure()
		}
	}
}

extension RSSParser: SAXParserDelegate {

	public func saxParser(_ saxParser: SAXParser, xmlStartElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?, namespaceCount: Int, namespaces: UnsafePointer<XMLPointer?>?, attributeCount: Int, attributesDefaultedCount: Int, attributes: UnsafePointer<XMLPointer?>?) {

		if endRSSFound {
			return
		}

		if SAXEqualTags(localName, XMLName.uppercaseRDF) {
			isRDF = true
			return
		}

		var xmlAttributes: XMLAttributesDictionary? = nil
		if (isRDF && SAXEqualTags(localName, XMLName.item)) || SAXEqualTags(localName, XMLName.guid) || SAXEqualTags(enclosure, XMLName.enclosure) {
			xmlAttributes = saxParser.attributesDictionary(attributes, attributeCount: attributeCount)
		}
		if currentAttributes != xmlAttributes {
			currentAttributes = xmlAttributes
		}

		if prefix == nil && SAXEqualTags(localName, XMLName.item) {
			addArticle()
			parsingArticle = true

			if isRDF && let rdfGuid = xmlAttributes?[XMLName.rdfAbout], let currentArticle { // RSS 1.0 guid
				currentArticle.guid = rdfGuid
				currentArticle.permalink = rdfGuid
			}
		}
		else if prefix == nil && SAXEqualTags(localName, XMLName.image) {
			parsingChannelImage = true
		}
		else if prefix == nil && SAXEqualTags(localName, XMLName.author) {
			if parsingArticle {
				parsingAuthor = true
			}
		}

		if !parsingChannelImage {
			saxParser.beginStoringCharacters()
		}
	}

	public func saxParser(_ saxParser: SAXParser, xmlEndElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?) {

		if endRSSFound {
			return
		}

		if isRDF && SAXEqualTags(localName, XMLName.uppercaseRDF) {
			endRSSFound = true
		}
		else if SAXEqualTags(localName, XMLName.rss) {
			endRSSFound = true
		}
		else if SAXEqualTags(localName, XMLName.image) {
			parsingChannelImage = false
		}
		else if SAXEqualTags(localName, XMLName.item) {
			parsingArticle = false
		}
		else if parsingArticle {
			addArticleElement(localName, prefix)
			if SAXEqualTags(localName, XMLName.author) {
				parsingAuthor = false
			}
		}
		else if !parsingChannelImage {
			addFeedElement(localName, prefix)
		}
	}

	public func saxParser(_ saxParser: SAXParser, xmlCharactersFound: XMLPointer, count: Int) {

		// Required method.
	}
}

