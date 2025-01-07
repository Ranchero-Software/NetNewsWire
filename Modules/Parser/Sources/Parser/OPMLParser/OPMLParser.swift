//
//  OPMLParser.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public final class OPMLParser {

	private let parserData: ParserData
	private var data: Data {
		parserData.data
	}

	private var opmlDocument: OPMLDocument?

	private var itemStack = [OPMLItem]()
	private var currentItem: OPMLItem? {
		itemStack.last
	}

	/// Returns nil if data can’t be parsed (if it’s not OPML).
	public static func document(with parserData: ParserData) -> OPMLDocument? {

		let opmlParser = OPMLParser(parserData)
		opmlParser.parse()
		return opmlParser.opmlDocument
	}

	init(_ parserData: ParserData) {
		self.parserData = parserData
	}
}

private extension OPMLParser {

	func parse() {

		guard canParseData() else {
			return
		}

		opmlDocument = OPMLDocument(url: parserData.url)
		push(opmlDocument!)

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

		itemStack.removeLast()
	}
}

extension OPMLParser: SAXParserDelegate {

	private struct XMLName {
		static let title = "title".utf8CString
		static let outline = "outline".utf8CString
	}

	public func saxParser(_ saxParser: SAXParser, xmlStartElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?, namespaceCount: Int, namespaces: UnsafePointer<XMLPointer?>?, attributeCount: Int, attributesDefaultedCount: Int, attributes: UnsafePointer<XMLPointer?>?) {

		if SAXEqualTags(localName, XMLName.title) {
			saxParser.beginStoringCharacters()
			return
		}

		if !SAXEqualTags(localName, XMLName.outline) {
			return
		}

		let attributesDictionary = saxParser.attributesDictionary(attributes, attributeCount: attributeCount)
		let item = OPMLItem(attributes: attributesDictionary)

		currentItem?.add(item)
		push(item)
	}

	public func saxParser(_ saxParser: SAXParser, xmlEndElement localName: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?) {

		if SAXEqualTags(localName, XMLName.title) {
			if let item = currentItem as? OPMLDocument {
				item.title = saxParser.currentStringWithTrimmedWhitespace
			}
			saxParser.endStoringCharacters()
			return
		}

		if SAXEqualTags(localName, XMLName.outline) {
			popItem()
		}
	}

	public func saxParser(_: SAXParser, xmlCharactersFound: XMLPointer, count: Int) {

		// Nothing to do, but method is required.
	}
}
