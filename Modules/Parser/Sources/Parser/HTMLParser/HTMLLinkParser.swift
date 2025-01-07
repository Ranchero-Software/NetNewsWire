//
//  HTMLLinkParser.swift
//  
//
//  Created by Brent Simmons on 9/21/24.
//

import Foundation
import RSCore
import os

public final class HTMLLinkParser {

	public private(set) var links = [HTMLLink]()
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "HTMLLinkParser")

	private let parserData: ParserData
	private let baseURL: URL?

	public static func htmlLinks(with parserData: ParserData) -> [HTMLLink] {

		let parser = HTMLLinkParser(parserData)
		parser.parse()
		return parser.links
	}

	init(_ parserData: ParserData) {

		self.parserData = parserData
		self.baseURL = URL(string: parserData.url)
	}
}

private extension HTMLLinkParser {

	func parse() {

		let htmlParser = SAXHTMLParser(delegate: self, data: parserData.data)
		htmlParser.parse()
	}
}

extension HTMLLinkParser: SAXHTMLParserDelegate {

	private var currentLink: HTMLLink? {
		links.last
	}

	private struct HTMLAttributeName {
		static let href = "href"
		static let title = "title"
	}

	private func title(with attributesDictionary: StringDictionary) -> String? {

		attributesDictionary.object(forCaseInsensitiveKey: HTMLAttributeName.title)
	}

	private func urlString(with attributesDictionary: StringDictionary) -> String? {

		guard let href = attributesDictionary.object(forCaseInsensitiveKey: HTMLAttributeName.href), !href.isEmpty else {
			return nil
		}

		guard let baseURL, let absoluteURL = URL(string: href, relativeTo: baseURL) else {
			Self.logger.info("Expected to create URL but got nil with \(href)")
			return nil
		}

		return absoluteURL.absoluteString
	}

	private func handleLinkAttributes(_ attributesDictionary: StringDictionary) {

		guard let currentLink else {
			assertionFailure("currentLink must not be nil")
			return
		}

		currentLink.urlString = urlString(with: attributesDictionary)
		currentLink.title = title(with: attributesDictionary)
	}

	private struct HTMLName {
		static let a = "a".utf8CString
	}

	public func saxHTMLParser(_ saxHTMLParser: SAXHTMLParser, startElement name: XMLPointer, attributes: UnsafePointer<XMLPointer?>?) {

		guard SAXEqualTags(name, HTMLName.a) else {
			return
		}

		let link = HTMLLink()
		links.append(link)

		if let attributesDictionary = saxHTMLParser.attributesDictionary(attributes) {
			handleLinkAttributes(attributesDictionary)
		}

		saxHTMLParser.beginStoringCharacters()
	}

	public func saxHTMLParser(_ saxHTMLParser: SAXHTMLParser, endElement name: XMLPointer) {

		guard SAXEqualTags(name, HTMLName.a) else {
			return
		}
		guard let currentLink else {
			assertionFailure("currentLink must not be nil.")
			return
		}

		currentLink.text = saxHTMLParser.currentStringWithTrimmedWhitespace
	}

	public func saxHTMLParser(_: SAXHTMLParser, charactersFound: XMLPointer, count: Int) {
		// Nothing needed.
	}
}
