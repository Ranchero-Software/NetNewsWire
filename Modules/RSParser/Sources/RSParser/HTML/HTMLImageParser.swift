//
//  HTMLImageParser.swift
//  RSParser
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation

/// Finds the first `<img>` in an HTML document that passes `SignificantImageFilter`,
/// which also sees the enclosing `<a>` link so it can reject share buttons.
/// Stops scanning once it finds one.
///
/// Uses `src`, falling back to the largest `srcset` candidate when `src` is
/// missing or a `data:` placeholder (as with lazy-loading images).
public enum HTMLImageParser {

	public static func firstSignificantImage(with parserData: ParserData) -> HTMLImage? {
		let delegate = ImageParserDelegate(baseURL: URL(string: parserData.url))
		let scanner = HTMLScanner(delegate: delegate)
		scanner.parse(Array(parserData.data))
		return delegate.image
	}
}

// MARK: - Delegate

private final class ImageParserDelegate: HTMLScannerDelegate {

	private let baseURL: URL?
	private(set) var image: HTMLImage?
	private var enclosingLinkURLString: String?

	private static let imgBytes: [UInt8] = Array("img".utf8)
	private static let anchorBytes: [UInt8] = Array("a".utf8)

	init(baseURL: URL?) {
		self.baseURL = baseURL
	}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didStartTag name: ArraySlice<UInt8>,
	                 attributes: HTMLAttributes,
	                 selfClosing: Bool) {
		if tagName(name, equals: Self.anchorBytes) {
			enclosingLinkURLString = resolvedURLString(attributes["href"])
			return
		}
		guard tagName(name, equals: Self.imgBytes) else {
			return
		}
		guard let urlString = imageURLString(attributes) else {
			return
		}

		let width = pixelDimension(attributes["width"])
		let height = pixelDimension(attributes["height"])
		guard SignificantImageFilter.isSignificant(urlString: urlString, width: width, height: height, htmlClass: attributes["class"], enclosingLinkURLString: enclosingLinkURLString) else {
			return
		}

		image = HTMLImage(urlString: urlString, width: width, height: height)
		scanner.stopParsing()
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

	private func imageURLString(_ attributes: HTMLAttributes) -> String? {
		resolvedURLString(imageSource(attributes))
	}

	private func resolvedURLString(_ urlString: String?) -> String? {
		guard let urlString else {
			return nil
		}
		return URL(string: urlString, relativeTo: baseURL)?.absoluteString
	}

	private func imageSource(_ attributes: HTMLAttributes) -> String? {
		if let src = attributes["src"]?.trimmingCharacters(in: .whitespacesAndNewlines), !src.isEmpty, !src.lowercased().hasPrefix("data:") {
			return src
		}
		guard let srcset = attributes["srcset"] else {
			return nil
		}
		return largestSrcsetCandidate(srcset)
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
