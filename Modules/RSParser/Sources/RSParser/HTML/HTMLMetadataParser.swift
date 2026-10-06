//
//  HTMLMetadataParser.swift
//  RSParser
//
//  Created by Brent Simmons on 4/19/26.
//

import Foundation

// Swift replacement for the ObjC RSHTMLMetadataParser.
// Collects `<link>` and `<meta>` tags from the HTML `<head>` and hands them
// to `HTMLMetadata.init(urlString:tags:)` for categorization (favicons,
// apple-touch-icons, feed links, OG, Twitter).
//
// Stops at the opening `<body>` tag, except for YouTube URLs — which are
// known to put feed-link tags in the body. The match is case-insensitive
// on the URL; matches like "youtubers" are harmless false positives.

public enum HTMLMetadataParser {

	public static func htmlMetadata(with parserData: ParserData) -> HTMLMetadata {
		let scanPastHead = parserData.url.range(of: "youtube", options: .caseInsensitive) != nil
		let delegate = MetadataParserDelegate(scanPastHead: scanPastHead)
		let scanner = HTMLScanner(delegate: delegate)
		scanner.parse(Array(parserData.data))
		return HTMLMetadata(urlString: parserData.url, tags: delegate.tags)
	}
}

// MARK: - Delegate

private final class MetadataParserDelegate: HTMLScannerDelegate {

	private let scanPastHead: Bool
	private var finished = false
	private(set) var tags: [HTMLTag] = []

	init(scanPastHead: Bool) {
		self.scanPastHead = scanPastHead
	}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didStartTag name: ArraySlice<UInt8>,
	                 attributes: HTMLAttributes,
	                 selfClosing: Bool) {
		if finished {
			return
		}

		if !scanPastHead && tagNameEqualsIgnoringCase(name, Self.bodyBytes) {
			finished = true
			return
		}

		if tagNameEqualsIgnoringCase(name, Self.linkBytes) {
			if attributes.isEmpty {
				return
			}
			// Match the ObjC parser: only collect <link> tags that carry both `rel`
			// and (`href` or `src`).
			guard let rel = attributes["rel"], !rel.isEmpty else {
				return
			}
			let link = attributes["href"] ?? attributes["src"]
			guard let link, !link.isEmpty else {
				return
			}
			tags.append(HTMLTag(type: .link, attributes: attributes.dictionary()))
			return
		}

		if tagNameEqualsIgnoringCase(name, Self.metaBytes) {
			if attributes.isEmpty {
				return
			}
			tags.append(HTMLTag(type: .meta, attributes: attributes.dictionary()))
		}
	}

	// MARK: Helpers

	static let bodyBytes: [UInt8] = Array("body".utf8)
	static let linkBytes: [UInt8] = Array("link".utf8)
	static let metaBytes: [UInt8] = Array("meta".utf8)

	private func tagNameEqualsIgnoringCase(_ name: ArraySlice<UInt8>, _ lowercased: [UInt8]) -> Bool {
		guard name.count == lowercased.count else {
			return false
		}
		for (a, b) in zip(name, lowercased) {
			if a.asciiLowercased != b {
				return false
			}
		}
		return true
	}
}
