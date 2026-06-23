//
//  HTMLLinkParser.swift
//  RSParser
//
//  Created by Brent Simmons on 4/19/26.
//

import Foundation

// Swift replacement for the ObjC RSHTMLLinkParser.
// Extracts every `<a>` element from an HTML document and returns an array of
// `HTMLLink` with absolute URL, title attribute, and trimmed inner text.
//
// Text accumulation follows the libxml2 behavior the original parser was
// measured against: a nested start tag resets the character buffer, so the
// text of `<a>before <b>after</b></a>` is "after", not "before after".

public enum HTMLLinkParser {

	public static func htmlLinks(with parserData: ParserData) -> [HTMLLink] {
		let delegate = LinkParserDelegate(baseURL: URL(string: parserData.url))
		let scanner = HTMLScanner(delegate: delegate)
		scanner.parse(Array(parserData.data))
		delegate.flushPending()
		return delegate.links
	}
}

// MARK: - Delegate

private final class LinkParserDelegate: HTMLScannerDelegate {

	private let baseURL: URL?
	private(set) var links: [HTMLLink] = []

	private var collectingText = false
	private var pendingURLString: String?
	private var pendingTitle: String?
	private var pendingText: [UInt8] = []

	init(baseURL: URL?) {
		self.baseURL = baseURL
	}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didStartTag name: ArraySlice<UInt8>,
	                 attributes: HTMLAttributes,
	                 selfClosing: Bool) {
		if isAnchorTag(name) {
			// A new <a> always starts a fresh pending link, flushing any still-open one.
			flushPending()
			pendingURLString = attributes["href"].flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteString }
			pendingTitle = attributes["title"]
			pendingText.removeAll(keepingCapacity: true)
			collectingText = true
			return
		}
		// A nested tag inside an anchor resets the text buffer, matching libxml2
		// SAX behavior (which fires startElement on nested tags and clears the
		// characters buffer). `<a>x<b>y</b></a>` yields text "y".
		if collectingText {
			pendingText.removeAll(keepingCapacity: true)
		}
	}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didEndTag name: ArraySlice<UInt8>) {
		if isAnchorTag(name) && collectingText {
			flushPending()
		}
	}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didFindCharacters bytes: ArraySlice<UInt8>) {
		if collectingText {
			pendingText.append(contentsOf: bytes)
		}
	}

	// MARK: Helpers

	func flushPending() {
		guard collectingText else {
			return
		}
		let decoded = String(decoding: pendingText, as: UTF8.self)
			.trimmingCharacters(in: .whitespacesAndNewlines)
		let text: String? = decoded.isEmpty ? nil : decoded
		links.append(HTMLLink(urlString: pendingURLString, text: text, title: pendingTitle))
		pendingURLString = nil
		pendingTitle = nil
		pendingText.removeAll(keepingCapacity: true)
		collectingText = false
	}

	private func isAnchorTag(_ name: ArraySlice<UInt8>) -> Bool {
		name.count == 1 && (name[name.startIndex] == .asciiLowerA || name[name.startIndex] == .asciiUpperA)
	}
}
