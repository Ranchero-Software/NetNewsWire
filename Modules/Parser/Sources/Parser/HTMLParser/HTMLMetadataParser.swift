//
//  HTMLMetadataParser.swift
//
//
//  Created by Brent Simmons on 9/22/24.
//

import Foundation
import RSCore

public final class HTMLMetadataParser {

	private var tags = [HTMLTag]()

	public static func metadata(with parserData: ParserData) -> HTMLMetadata {

		HTMLMetadataParser().parse(parserData)
	}
}

private extension HTMLMetadataParser {

	func parse(_ parserData: ParserData) -> HTMLMetadata {

		tags = [HTMLTag]()

		let htmlParser = SAXHTMLParser(delegate: self, data: parserData.data)
		htmlParser.parse()

		return HTMLMetadata(parserData.url, tags)
	}
}

extension HTMLMetadataParser: SAXHTMLParserDelegate {

	private struct HTMLName {

		static let link = "link".utf8CString
		static let meta = "meta".utf8CString
	}

	private struct HTMLKey {

		static let href = "href"
		static let src = "src"
		static let rel = "rel"
	}

	private func link(with attributes: StringDictionary) -> String? {

		if let link = attributes.object(forCaseInsensitiveKey: HTMLKey.href) {
			return link
		}

		return attributes.object(forCaseInsensitiveKey: HTMLKey.src)
	}

	private func handleLinkAttributes(_ attributes: StringDictionary) {

		guard let rel = attributes.object(forCaseInsensitiveKey: HTMLKey.rel), !rel.isEmpty else {
			return
		}
		guard let link = link(with: attributes), !link.isEmpty else {
			return
		}

		let tag = HTMLTag(tagType: .link, attributes: attributes)
		tags.append(tag)
	}

	private func handleMetaAttributes(_ attributes: StringDictionary) {

		let tag = HTMLTag(tagType: .meta, attributes: attributes)
		tags.append(tag)
	}

	public func saxHTMLParser(_ saxHTMLParser: SAXHTMLParser, startElement name: XMLPointer, attributes: UnsafePointer<XMLPointer?>?) {

		if SAXEqualTags(name, HTMLName.link) {
			let d = saxHTMLParser.attributesDictionary(attributes)
			if let d, !d.isEmpty {
				handleLinkAttributes(d)
			}
		} else if SAXEqualTags(name, HTMLName.meta) {
			let d = saxHTMLParser.attributesDictionary(attributes)
			if let d, !d.isEmpty {
				handleMetaAttributes(d)
			}
		}
	}

	public func saxHTMLParser(_: SAXHTMLParser, endElement: XMLPointer) {

		// Nothing to do
	}

	public func saxHTMLParser(_: SAXHTMLParser, charactersFound: XMLPointer, count: Int) {

		// Nothing to do
	}
}
