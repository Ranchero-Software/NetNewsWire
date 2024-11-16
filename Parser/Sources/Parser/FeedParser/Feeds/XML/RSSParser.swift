//
//  RSSParser.swift
//  Parser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

public final class RSSParser {

	private let feedURL: String
	private let data: Data
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
	private var currentAttributes: StringDictionary?

	static func parsedFeed(urlString: String, data: Data) -> RSSFeed {

		let parser = RSSParser(urlString: urlString, data: data)
		parser.parse()
		return parser.feed
	}

	init(urlString: String, data: Data) {
		self.feedURL = urlString
		self.data = data
		self.feed = RSSFeed(urlString: urlString)
	}
}

private extension RSSParser {

	func parse() {

		let saxParser = SAXParser(delegate: self, data: data)
		saxParser.parse()
		feed.articles = articles
	}

	private struct XMLName {
		static let uppercaseRDF = "RDF".utf8CString
		static let item = "item".utf8CString
		static let guid = "guid".utf8CString
		static let enclosure = "enclosure".utf8CString
		static let image = "image".utf8CString
		static let author = "author".utf8CString
		static let rss = "rss".utf8CString
		static let link = "link".utf8CString
		static let title = "title".utf8CString
		static let language = "language".utf8CString
		static let dc = "dc".utf8CString
		static let content = "content".utf8CString
		static let encoded = "encoded".utf8CString
		static let creator = "creator".utf8CString
		static let date = "date".utf8CString
		static let pubDate = "pubDate".utf8CString
		static let description = "description".utf8CString
	}

	func addFeedElement(_ saxParser: SAXParser, _ localName: XMLPointer, _ prefix: XMLPointer?) {

		guard prefix == nil else {
			return
		}

		if SAXEqualTags(localName, XMLName.link) {
			if feed.link == nil {
				feed.link = saxParser.currentString
			}
		}
		else if SAXEqualTags(localName, XMLName.title) {
			feed.title = saxParser.currentString
		}
		else if SAXEqualTags(localName, XMLName.language) {
			feed.language = saxParser.currentString
		}
	}

	func addArticle() {
		let article = RSSArticle(feedURL)
		articles.append(article)
	}

	func addArticleElement(_ saxParser: SAXParser, _ localName: XMLPointer, _ prefix: XMLPointer?) {

		guard let currentArticle else {
			return
		}

		if let prefix, SAXEqualTags(prefix, XMLName.dc) {
			addDCElement(saxParser, localName, currentArticle)
			return
		}

		if let prefix, SAXEqualTags(prefix, XMLName.content) && SAXEqualTags(localName, XMLName.encoded) {
			if let currentString = saxParser.currentString, !currentString.isEmpty {
				currentArticle.body = currentString
			}
			return
		}

		guard prefix == nil else {
			return
		}

		if let currentString = saxParser.currentString {
			if SAXEqualTags(localName, XMLName.guid) {
				addGuid(currentString, currentArticle)
			}
			else if SAXEqualTags(localName, XMLName.author) {
				addAuthorWithString(currentString, currentArticle)
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
				currentArticle.title = currentString
			}
			else if SAXEqualTags(localName, XMLName.pubDate) {
				currentArticle.datePublished = currentDate(saxParser)
			}
		}
		else if SAXEqualTags(localName, XMLName.enclosure), let currentAttributes {
			addEnclosure(currentAttributes, currentArticle)
		}
	}

	func addDCElement(_ saxParser: SAXParser, _ localName: XMLPointer, _ currentArticle: RSSArticle) {

		if SAXEqualTags(localName, XMLName.creator) {
			if let currentString = saxParser.currentString {
				addAuthorWithString(currentString, currentArticle)
			}
		}
		else if SAXEqualTags(localName, XMLName.date) {
			currentArticle.datePublished = currentDate(saxParser)
		}
	}

	static let isPermalinkKey = "isPermaLink"
	static let isPermalinkLowercaseKey = "ispermalink"
	static let falseValue = "false"

	func addGuid(_ guid: String, _ currentArticle: RSSArticle) {

		currentArticle.guid = guid

		guard let currentAttributes else {
			return
		}

		let isPermaLinkValue: String? = {

			if let value = currentAttributes[Self.isPermalinkKey] {
				return value
			}
			// Allow for `ispermalink`, `isPermalink`, etc.
			for (key, value) in currentAttributes {
				if key.lowercased() == Self.isPermalinkLowercaseKey {
					return value
				}
			}

			return nil
		}()

		// Spec: `isPermaLink is optional, its default value is true.`
		// https://cyber.harvard.edu/rss/rss.html#ltguidgtSubelementOfLtitemgt
		// Return only if non-nil and equal to false — otherwise it’s a permalink.
		if let isPermaLinkValue, isPermaLinkValue == Self.falseValue {
			return
		}

		// Feed bug found in the wild: using a guid that’s not really a permalink
		// and not realizing that `isPermaLink` is true by default.
		if stringIsProbablyAURLOrRelativePath(guid) {
			currentArticle.permalink = urlString(guid)
		}
	}

	func stringIsProbablyAURLOrRelativePath(_ s: String) -> Bool {

		// The RSS guid is defined as a permalink, except when it appears like this:
		// `<guid isPermaLink="false">some—identifier</guid>`
		// However, people often seem to think it’s *not* a permalink by default, even
		// though it is. So we try to detect the situation where the value is not a URL string,
		// and not even a relative path. This may need to evolve over time.

		if !s.contains("/") {
			// This seems to be just about the best possible check.
			// Bad guids are often just integers, for instance.
			return false
		}

		if s.lowercased().hasPrefix("tag:") {
			// A common non-URL guid form starts with `tag:`.
			return false
		}

		return true
	}

	/// Do best attempt at turning a string into a URL string.
	///
	/// If it already appears to be a URL, return it.
	/// Otherwise, treat it like a relative URL and resolve using
	/// the URL of the home page of the feed (if available)
	/// or the URL of the feed.
	///
	/// The returned value is not guaranteed to be a valid URL string.
	/// It’s a best attempt without going to heroic lengths.
	func urlString(_ s: String) -> String {

		if s.lowercased().hasPrefix("http") {
			return s
		}

		let baseURLString = feed.link ?? feedURL
		guard let baseURL = URL(string: baseURLString) else {
			return s
		}
		guard let resolvedURL = URL(string: s, relativeTo: baseURL) else {
			return s
		}

		return resolvedURL.absoluteString
	}

	func addAuthorWithString(_ authorString: String, _ currentArticle: RSSArticle) {

		if authorString.isEmpty {
			return
		}

		let author = RSSAuthor(singleString: authorString)
		currentArticle.addAuthor(author)
	}

	private struct EnclosureKey {
		static let url = "url"
		static let length = "length"
		static let type = "type"
	}

	func addEnclosure(_ attributes: StringDictionary, _ currentArticle: RSSArticle) {

		guard let url = attributes[EnclosureKey.url], !url.isEmpty else {
			return
		}

		let enclosure = RSSEnclosure(url: url)
		if let lengthValue = attributes[EnclosureKey.length], let length = Int(lengthValue) {
			enclosure.length = length
		}
		enclosure.mimeType = attributes[EnclosureKey.type]

		currentArticle.addEnclosure(enclosure)
	}

	func currentDate(_ saxParser: SAXParser) -> Date? {

		guard let data = saxParser.currentCharacters else {
			return nil
		}
		return DateParser.date(data: data)
	}
}

extension RSSParser: SAXParserDelegate {

	static let rdfAbout = "rdf:about"

	public func saxParser(_ saxParser: SAXParser, xmlStartElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?, namespaceCount: Int, namespaces: UnsafePointer<XMLPointer?>?, attributeCount: Int, attributesDefaultedCount: Int, attributes: UnsafePointer<XMLPointer?>?) {

		if endRSSFound {
			return
		}

		if SAXEqualTags(localName, XMLName.uppercaseRDF) {
			isRDF = true
			return
		}

		var xmlAttributes: StringDictionary? = nil
		if (isRDF && SAXEqualTags(localName, XMLName.item)) || SAXEqualTags(localName, XMLName.guid) || SAXEqualTags(localName, XMLName.enclosure) {
			xmlAttributes = saxParser.attributesDictionary(attributes, attributeCount: attributeCount)
		}
		if currentAttributes != xmlAttributes {
			currentAttributes = xmlAttributes
		}

		if prefix == nil && SAXEqualTags(localName, XMLName.item) {
			addArticle()
			parsingArticle = true

			if isRDF, let rdfGuid = xmlAttributes?[Self.rdfAbout], let currentArticle { // RSS 1.0 guid
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
			addArticleElement(saxParser, localName, prefix)
			if SAXEqualTags(localName, XMLName.author) {
				parsingAuthor = false
			}
		}
		else if !parsingChannelImage {
			addFeedElement(saxParser, localName, prefix)
		}
	}

	public func saxParser(_ saxParser: SAXParser, xmlCharactersFound: XMLPointer, count: Int) {

		// Required method.
	}
}

