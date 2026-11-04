//
//  HTMLImageAttributeInserter.swift
//  RSParser
//
//  Created by Brent Simmons on 10/27/26.
//

import Foundation

/// Inserts attributes at the start of the `<img>` tags that load a given URL from `src`.
///
/// HTML uses the first of two attributes with the same name, so an inserted `src`
/// replaces the original one, which stays in the tag unchanged.
///
/// Skips images whose `src` a web view may not load: those with `srcset`,
/// those inside `<picture>`, and those with `data-canonical-src`, which script replaces `src` with.
public enum HTMLImageAttributeInserter {

	/// `attributes` is inserted as is, so it must be escaped HTML, starting with a space.
	public static func insertingAttributes(_ attributes: String, intoImagesWithSource urlString: String, html: String, baseURL: URL?) -> String {
		let bytes = Array(html.utf8)
		let delegate = InserterDelegate(urlString: urlString, baseURL: baseURL)
		let scanner = HTMLScanner(delegate: delegate)
		scanner.parse(bytes)
		guard !delegate.insertionOffsets.isEmpty else {
			return html
		}

		let attributeBytes = Array(attributes.utf8)
		var result = [UInt8]()
		result.reserveCapacity(bytes.count + attributeBytes.count * delegate.insertionOffsets.count)
		var copyStart = 0
		for offset in delegate.insertionOffsets {
			result.append(contentsOf: bytes[copyStart..<offset])
			result.append(contentsOf: attributeBytes)
			copyStart = offset
		}
		result.append(contentsOf: bytes[copyStart...])
		return String(decoding: result, as: UTF8.self)
	}
}

// MARK: - Delegate

private final class InserterDelegate: HTMLScannerDelegate {

	private let urlString: String
	private let baseURL: URL?
	private(set) var insertionOffsets = [Int]() // Just past each matching tag name
	private var pictureDepth = 0

	private static let imgBytes: [UInt8] = Array("img".utf8)
	private static let pictureBytes: [UInt8] = Array("picture".utf8)

	init(urlString: String, baseURL: URL?) {
		self.urlString = urlString
		self.baseURL = baseURL
	}

	func htmlScanner(_ scanner: HTMLScanner, didStartTag name: ArraySlice<UInt8>, attributes: HTMLAttributes, selfClosing: Bool) {
		if HTMLScanner.tagNameEqualsIgnoringCase(name, Self.pictureBytes[...]) {
			if !selfClosing {
				pictureDepth += 1
			}
			return
		}
		guard pictureDepth == 0, HTMLScanner.tagNameEqualsIgnoringCase(name, Self.imgBytes[...]) else {
			return
		}
		guard attributes["srcset"] == nil, attributes["data-canonical-src"] == nil else {
			return
		}
		if HTMLImageParser.resolvedURLString(attributes["src"], baseURL: baseURL) == urlString {
			// The name slice’s indices are offsets into the scanned bytes.
			insertionOffsets.append(name.endIndex)
		}
	}

	func htmlScanner(_ scanner: HTMLScanner, didEndTag name: ArraySlice<UInt8>) {
		if pictureDepth > 0, HTMLScanner.tagNameEqualsIgnoringCase(name, Self.pictureBytes[...]) {
			pictureDepth -= 1
		}
	}
}
