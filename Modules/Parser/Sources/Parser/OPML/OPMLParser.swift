//
//  OPMLParser.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public final class OPMLParser {

	private let url: String
	private let data: Data

	private let opmlDocument: OPMLDocument

	private var itemStack = [OPMLItem]()
	private var currentItem: OPMLItem? {
		itemStack.last
	}

	struct XMLKey {
		static let title = "title".utf8CString
		static let outline = "outline".utf8CString
	}

	/// Returns nil if data can’t be parsed (if it’s not OPML).
	public static func document(with parserData: ParserData) -> OPMLDocument? {

		let opmlParser = OPMLParser(parserData)
		return opmlParser.parse()
	}

	init(_ parserData: ParserData) {

		self.url = parserData.url
		self.data = parserData.data
		self.opmlDocument = OPMLDocument(url: parserData.url)
	}
}

private extension OPMLParser {

	func parse() -> OPMLDocument? {

		guard canParseData() else {
			return nil
		}

		pushItem(opmlDocument)

		let saxParser = SAXParser(delegate: self, data: data)
		saxParser.parse()
	}

	func canParseData() -> Bool {
		
		data.containsASCIIString("<opml")
	}

	func push(_ item: OPMLItem) {

		itemStack.append(item)
	}

	func popItem() {

		guard itemStack.count > 0 else {
			assertionFailure("itemStack.count must be > 0")
			return
		}

		itemStack.dropLast()
	}
}

extension OPMLParser: SAXParserDelegate {

	func saxParser(_ saxParser: SAXParser, xmlStartElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?, namespaceCount: Int, namespaces: UnsafeMutablePointer<XMLPointer?>?, attributeCount: Int, attributesDefaultedCount: Int, attributes: UnsafeMutablePointer<XMLPointer?>?) {

		if SAXEqualStrings(localName, XMLKey.title) {
			saxParser.beginStoringCharacters()
			return
		}

		if !SAXEqualStrings(localName, XMLKey.outline) {
			return
		}

		let attributesDictionary = saxParser.attributesDictionary(attributes, attributeCount: attributeCount)
		let item = OPMLItem(attributes: attributesDictionary)

		currentItem?.add(item)
		push(item)
	}

	func saxParser(_ saxParser: SAXParser, xmlEndElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?) {

		if SAXEqualStrings(localname, XMLKey.title) {
			if let item = currentItem as? OPMLDocument {
				item.title = saxParser.currentStringWithTrimmedWhitespace
			}
			return
		}

		if SAXEqualStrings(localName, XMLKey.outline) {
			popItem()
		}
	}

	func saxParser(_: SAXParser, xmlCharactersFound: XMLPointer, count: Int) {

		// Nothing to do, but method is required.
	}
}
