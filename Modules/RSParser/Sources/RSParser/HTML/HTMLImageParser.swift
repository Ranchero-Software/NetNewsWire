//
//  HTMLImageParser.swift
//  RSParser
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation

/// Finds the `<img>`s in an HTML document that pass `SignificantImageFilter`,
/// which also sees the enclosing `<a>` link so it can reject share buttons.
/// Stops scanning once it has found `maximumCount`.
///
/// Tries `data-lazy-src`, `data-src`, `src`, and the largest `srcset` candidate,
/// in that order, and uses the first that passes the filter. Lazy-loading images
/// often have a placeholder in `src`.
public enum HTMLImageParser {

	/// In document order, with no repeated URLs.
	public static func significantImages(with parserData: ParserData, maximumCount: Int) -> [HTMLImage] {
		let delegate = ImageParserDelegate(baseURL: URL(string: parserData.url), maximumCount: maximumCount)
		let scanner = HTMLScanner(delegate: delegate)
		scanner.parse(Array(parserData.data))
		return delegate.images
	}

	/// Nil for an empty string or a `data:` URL.
	static func resolvedURLString(_ urlString: String?, baseURL: URL?) -> String? {
		guard let urlString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !urlString.isEmpty, !urlString.lowercased().hasPrefix("data:") else {
			return nil
		}
		return URL(string: urlString, relativeTo: baseURL)?.absoluteString
	}
}

// MARK: - Delegate

private final class ImageParserDelegate: HTMLScannerDelegate {

	private let baseURL: URL?
	private let maximumCount: Int
	private(set) var images = [HTMLImage]()
	private var enclosingLinkURLString: String?

	private static let imgBytes: [UInt8] = Array("img".utf8)
	private static let anchorBytes: [UInt8] = Array("a".utf8)
	private static let sourceAttributeNames = ["data-lazy-src", "data-src", "src"]

	init(baseURL: URL?, maximumCount: Int) {
		self.baseURL = baseURL
		self.maximumCount = maximumCount
	}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didStartTag name: ArraySlice<UInt8>,
	                 attributes: HTMLAttributes,
	                 selfClosing: Bool) {
		if tagName(name, equals: Self.anchorBytes) {
			enclosingLinkURLString = resolvedURLString(attributes["href"])
			return
		}
		guard images.count < maximumCount, tagName(name, equals: Self.imgBytes) else {
			return
		}

		let width = pixelDimension(attributes["width"])
		let height = pixelDimension(attributes["height"])
		let htmlClass = attributes["class"]
		for urlString in imageURLStrings(attributes) {
			if SignificantImageFilter.isSignificant(urlString: urlString, width: width, height: height, htmlClass: htmlClass, enclosingLinkURLString: enclosingLinkURLString) {
				if !images.contains(where: { $0.urlString == urlString }) {
					images.append(HTMLImage(urlString: urlString, width: width, height: height))
				}
				if images.count >= maximumCount {
					scanner.stopParsing()
				}
				return
			}
		}
	}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didEndTag name: ArraySlice<UInt8>) {
		if tagName(name, equals: Self.anchorBytes) {
			enclosingLinkURLString = nil
		}
	}

	// MARK: Helpers

	/// `lowercasedName` must be all lowercase.
	private func tagName(_ name: ArraySlice<UInt8>, equals lowercasedName: [UInt8]) -> Bool {
		guard name.count == lowercasedName.count else {
			return false
		}
		return zip(name, lowercasedName).allSatisfy { $0.asciiLowercased == $1 }
	}

	private func imageURLStrings(_ attributes: HTMLAttributes) -> [String] {
		var sources = Self.sourceAttributeNames.compactMap { attributes[$0] }
		if let srcset = attributes["srcset"], let candidate = largestSrcsetCandidate(srcset) {
			sources.append(candidate)
		}
		return sources.compactMap(resolvedURLString)
	}

	private func resolvedURLString(_ urlString: String?) -> String? {
		HTMLImageParser.resolvedURLString(urlString, baseURL: baseURL)
	}

	/// The URL with the largest width (`640w`) or density (`2x`) descriptor. A candidate with no descriptor counts as `1x`.
	private func largestSrcsetCandidate(_ srcset: String) -> String? {
		var largest: (url: Substring, size: Double)?
		var remaining = srcset[...]

		while true {
			remaining = remaining.drop { $0.isWhitespace || $0 == "," }
			if remaining.isEmpty {
				break
			}

			var url = remaining.prefix { !$0.isWhitespace }
			remaining = remaining.dropFirst(url.count)

			// A URL ending in a comma has no descriptor.
			var descriptor: Substring = ""
			if url.hasSuffix(",") {
				while url.hasSuffix(",") {
					url = url.dropLast()
				}
			} else {
				descriptor = remaining.prefix { $0 != "," }
				remaining = remaining.dropFirst(descriptor.count)
			}

			let size = Double(descriptor.trimmingCharacters(in: .whitespaces).dropLast()) ?? 1
			if url.isEmpty {
				continue
			}
			if let largest, largest.size >= size {
				continue
			}
			largest = (url: url, size: size)
		}

		guard let largest else {
			return nil
		}
		return String(largest.url)
	}

	/// `"300"` and `"300px"` are pixel dimensions. Percentages and other units are not.
	private func pixelDimension(_ value: String?) -> Int? {
		guard var value = value?.trimmingCharacters(in: .whitespaces).lowercased() else {
			return nil
		}
		if value.hasSuffix("px") {
			value.removeLast(2)
		}
		return Int(value)
	}
}
