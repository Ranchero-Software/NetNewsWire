//
//  OPMLParser.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation

public enum OPMLParser {

	/// Parse OPML data. Throws `OPMLError.dataIsWrongFormat` if the data doesn't look like OPML.
	public static func parseOPML(with parserData: ParserData) throws -> OPMLDocument {
		let bytes = Array(parserData.data)
		try validateLooksLikeOPML(bytes: bytes, urlString: parserData.url)

		let delegate = OPMLParserDelegate(urlString: parserData.url)
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(bytes)
		return delegate.document
	}

	private static func validateLooksLikeOPML(bytes: [UInt8], urlString: String) throws {
		// Look for `<opml` (case-insensitive) in the first 4 KB.
		let limit = Swift.min(bytes.count, 4096)
		let needle: [UInt8] = Array("opml".utf8)
		var i = 0
		while i + needle.count + 1 <= limit {
			if bytes[i] == UInt8.asciiLessThan {
				let start = i + 1
				var match = true
				for k in 0..<needle.count {
					if bytes[start + k].asciiLowercased != needle[k] {
						match = false
						break
					}
				}
				if match {
					return
				}
			}
			i += 1
		}

		let url = URL(string: urlString)
		let filename: String = url?.isFileURL == true ? (url?.lastPathComponent ?? urlString) : urlString
		throw OPMLError.dataIsWrongFormat(fileName: filename)
	}
}

// MARK: - Delegate

private final class OPMLParserDelegate: XMLSAXParserDelegate {

	let document: OPMLDocument
	private var itemStack: [OPMLItem]
	private var collectingTitleOnDocument = false

	init(urlString: String) {
		let doc = OPMLDocument(url: urlString)
		self.document = doc
		self.itemStack = [doc]
	}

	private var currentItem: OPMLItem {
		itemStack.last ?? document
	}

	// MARK: Start

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didStartElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace,
	                  attributes: XMLAttributes) {
		if localName.equals("title") {
			parser.beginStoringCharacters()
			collectingTitleOnDocument = (itemStack.count == 1) // only document-level title matters
			return
		}

		if !localName.equals("outline") {
			return
		}

		let item = OPMLItem(attributes: attributes.dictionary())
		currentItem.addChild(item)
		itemStack.append(item)
	}

	// MARK: End

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didEndElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace) {
		if localName.equals("title") {
			if collectingTitleOnDocument {
				document.title = parser.currentStringWithTrimmedWhitespace
			}
			collectingTitleOnDocument = false
			return
		}

		if localName.equals("outline") {
			if itemStack.count > 1 {
				itemStack.removeLast()
			}
		}
	}
}
