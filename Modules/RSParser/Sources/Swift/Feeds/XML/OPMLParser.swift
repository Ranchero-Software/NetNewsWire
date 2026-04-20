//
//  OPMLParser.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation
#if SWIFT_PACKAGE
import RSParserObjC
#endif

// Swift replacement for the ObjC RSOPMLParser.
// Same public entry point (`RSOPMLParser.parseOPML(with:)`) and returns the
// same ObjC RSOPMLDocument type so the Account module keeps working unchanged.
// Parsing is driven by the pure-Swift XMLSAXParser.

public final class RSOPMLParser: NSObject {

	/// Parse OPML data. Throws `RSOPMLWrongFormatError` if the data doesn't look like OPML.
	public static func parseOPML(with parserData: ParserData) throws -> RSOPMLDocument {
		let bytes = Array(parserData.data)
		try validateLooksLikeOPML(bytes: bytes, urlString: parserData.url)

		let delegate = OPMLParserDelegate(urlString: parserData.url)
		let parser = XMLSAXParser(delegate: delegate)
		parser.parse(bytes)
		return delegate.document
	}

	private static func validateLooksLikeOPML(bytes: [UInt8], urlString: String) throws {
		// Same heuristic as the old parser: look for `<opml` (case-insensitive) in the first 4 KB.
		let limit = Swift.min(bytes.count, 4096)
		let needle: [UInt8] = [0x6F, 0x70, 0x6D, 0x6C] // "opml"
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
		throw NSError(domain: RSOPMLErrorDomain, code: RSOPMLErrorCode.dataIsWrongFormat.rawValue, userInfo: [
			NSLocalizedDescriptionKey: "The file ‘\(filename)’ can’t be parsed because it’s not an OPML file.",
			NSLocalizedFailureReasonErrorKey: "The file is not an OPML file."
		])
	}
}

// MARK: - Delegate

private final class OPMLParserDelegate: XMLSAXParserDelegate {

	let document: RSOPMLDocument
	private var itemStack: [RSOPMLItem]
	private var collectingTitleOnDocument = false

	init(urlString: String) {
		let doc = RSOPMLDocument()
		doc.url = urlString
		self.document = doc
		self.itemStack = [doc]
	}

	private var currentItem: RSOPMLItem {
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

		let item = RSOPMLItem()
		item.attributes = attributes.dictionary()
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
