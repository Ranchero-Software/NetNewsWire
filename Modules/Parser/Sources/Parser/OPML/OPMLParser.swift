//
//  OPMLParser.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public final class OPMLParser {

	let url: String
	let data: Data

	private var itemStack = [OPMLItem]()
	
	enum OPMLParserError: Error {
		case notOPML
	}

	init(parserData: ParserData) {

		self.url = parserData.url
		self.data = parserData.data
	}

	func parse() throws -> OPMLDocument? {

		guard canParseData() else {
			throw OPMLParserError.notOPML
		}

		let parser = SAXParser(delegate: self, data: data)
		

	}
}

extension OPMLParser: SAXParserDelegate {

	func saxParser(_: SAXParser, xmlStartElement: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?, namespaceCount: Int, namespaces: UnsafeMutablePointer<XMLPointer?>?, attributeCount: Int, attributesDefaultedCount: Int, attributes: UnsafeMutablePointer<XMLPointer?>?) {

	}

	func saxParser(_: SAXParser, xmlEndElement: XMLPointer, prefix: XMLPointer?, uri: XMLPointer?) {

	}

	func saxParser(_: SAXParser, xmlCharactersFound: XMLPointer, count: Int) {

	}

	func saxParser(_: SAXParser, internedStringForName: XMLPointer, prefix: XMLPointer?) -> String? {

	}

	func saxParser(_: SAXParser, internedStringForValue: XMLPointer, count: Int) -> String? {

	}
}
