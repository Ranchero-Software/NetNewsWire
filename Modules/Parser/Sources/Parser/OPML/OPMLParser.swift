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

	func pushItem(_ item: OPMLItem) {

		itemStack.append(item)
	}

	func popItem() {

		assert(itemStack.count > 0)
		guard itemStack.count > 0 else {
			assertionFailure("itemStack.count must be > 0")
		}

		itemStack.dropLast()
	}
}

extension OPMLParser: SAXParserDelegate {

	func saxParser(_: SAXParser, xmlStartElement: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?, namespaceCount: Int, namespaces: UnsafeMutablePointer<XMLPointer?>?, attributeCount: Int, attributesDefaultedCount: Int, attributes: UnsafeMutablePointer<XMLPointer?>?) {

	}

	func saxParser(_: SAXParser, xmlEndElement: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?) {

	}

	func saxParser(_: SAXParser, xmlCharactersFound: XMLPointer, count: Int) {

	}
}
