//
//  HTMLMetadataParser.swift
//
//
//  Created by Brent Simmons on 9/22/24.
//

import Foundation
import SAX

public final class HTMLMetadataParser {

	private let parserData: ParserData
	private var tags = [HTMLTag]()
	private var htmlMetadata: HTMLMetadata? = nil

	public static func metadata(with parserData: ParserData) -> HTMLMetadata {

		let parser = HTMLMetadataParser(parserData)
		parser.parse()
		return parser.htmlMetadata
	}

	init(_ parserData: ParserData) {

		self.parserData = parserData
	}
}

private extension HTMLMetadataParser {

	func parse() {

		self.tags = [HTMLTag]()

		let htmlParser = SAXHTMLParser(delegate: self, data: parserData.data)
		htmlParser.parse()

		self.htmlMetadata = HTMLMetadata(parserData.url, tags)
	}
}
