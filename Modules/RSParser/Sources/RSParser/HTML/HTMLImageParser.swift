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
/// Tries `data-lazy-srcset`, `data-srcset`, `data-lazy-src`, `data-src`, `data-original`,
/// `srcset`, and `src`, in that order, and uses the first that passes the filter.
/// Lazy-loading images often have a placeholder in `src`.
public enum HTMLImageParser {

	private static let dataURLPrefix = "data:"

	/// Absolute URLs, resolved against `baseURL`, in document order, with none repeated.
	public static func significantImageURLStrings(html: String, baseURL: URL?, maximumCount: Int) -> [String] {
		let delegate = ImageParserDelegate(baseURL: baseURL, maximumCount: maximumCount)
		let scanner = HTMLScanner(delegate: delegate)
		scanner.parse(Array(html.utf8))
		return delegate.urlStrings
	}

	/// Nil for an empty string or a `data:` URL.
	static func resolvedURLString(_ urlString: String?, baseURL: URL?) -> String? {
		guard let urlString, !isDataURL(urlString) else {
			return nil
		}
		let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedURLString.isEmpty else {
			return nil
		}
		return URL(string: trimmedURLString, relativeTo: baseURL)?.absoluteString
	}

	/// Looks at only the start of the string, since an inline image can be megabytes.
	private static func isDataURL(_ urlString: String) -> Bool {
		urlString.drop(while: \.isWhitespace).prefix(dataURLPrefix.count).lowercased() == dataURLPrefix
	}
}

// MARK: - Delegate

private final class ImageParserDelegate: HTMLScannerDelegate {

	private let baseURL: URL?
	private let maximumCount: Int
	private(set) var urlStrings = [String]()
	private var enclosingLinkURLString: String?

	private static let imgBytes: [UInt8] = Array("img".utf8)
	private static let anchorBytes: [UInt8] = Array("a".utf8)
	private static let lazySrcsetAttributeNames = ["data-lazy-srcset", "data-srcset"]
	private static let lazySourceAttributeNames = ["data-lazy-src", "data-src", "data-original"]
	/// Wide enough for a timeline thumbnail at its largest.
	private static let preferredSrcsetWidth: Double = 1200

	init(baseURL: URL?, maximumCount: Int) {
		self.baseURL = baseURL
		self.maximumCount = maximumCount
	}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didStartTag name: ArraySlice<UInt8>,
	                 attributes: HTMLAttributes,
	                 selfClosing: Bool) {
		if HTMLScanner.tagNameEqualsIgnoringCase(name, Self.anchorBytes[...]) {
			enclosingLinkURLString = resolvedURLString(attributes["href"])
			return
		}
		guard urlStrings.count < maximumCount, HTMLScanner.tagNameEqualsIgnoringCase(name, Self.imgBytes[...]) else {
			return
		}

		let style = styleProperties(attributes["style"])
		if attributes["hidden"] != nil || style["display"]?.hasPrefix("none") == true {
			return
		}

		// CSS overrides the attributes.
		let width = pixelDimension(style["width"]) ?? pixelDimension(attributes["width"])
		let height = pixelDimension(style["height"]) ?? pixelDimension(attributes["height"])
		// Before resolving any URLs, since tracking pixels are common.
		guard SignificantImageFilter.hasSignificantDimensions(width: width, height: height) else {
			return
		}
		let htmlClass = attributes["class"]
		for urlString in imageURLStrings(attributes) {
			if SignificantImageFilter.isSignificant(urlString: urlString, width: width, height: height, htmlClass: htmlClass, enclosingLinkURLString: enclosingLinkURLString) {
				if !urlStrings.contains(urlString) {
					urlStrings.append(urlString)
				}
				if urlStrings.count >= maximumCount {
					scanner.stopParsing()
				}
				return
			}
		}
	}

	func htmlScanner(_ scanner: HTMLScanner,
	                 didEndTag name: ArraySlice<UInt8>) {
		if HTMLScanner.tagNameEqualsIgnoringCase(name, Self.anchorBytes[...]) {
			enclosingLinkURLString = nil
		}
	}

	// MARK: Helpers

	/// Resolved as needed, since usually the first is used.
	private func imageURLStrings(_ attributes: HTMLAttributes) -> some Sequence<String> {
		var sources = Self.lazySrcsetAttributeNames.compactMap { attributes[$0] }.compactMap(preferredSrcsetCandidate)
		sources += Self.lazySourceAttributeNames.compactMap { attributes[$0] }
		if let srcset = attributes["srcset"], let candidate = preferredSrcsetCandidate(srcset) {
			sources.append(candidate)
		}
		if let src = attributes["src"] {
			sources.append(src)
		}
		return sources.lazy.compactMap { self.resolvedURLString($0) }
	}

	private func resolvedURLString(_ urlString: String?) -> String? {
		HTMLImageParser.resolvedURLString(urlString, baseURL: baseURL)
	}

	/// The narrowest URL with a width descriptor (`640w`) of at least `preferredSrcsetWidth`.
	/// Otherwise, the URL with the largest width or density (`2x`) descriptor. A candidate with no descriptor counts as `1x`.
	private func preferredSrcsetCandidate(_ srcset: String) -> String? {
		var narrowestWideEnough: (url: Substring, size: Double)?
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

			// A descriptor can have a second part, as in `400w 300h`.
			let sizeDescriptor = descriptor.split(whereSeparator: \.isWhitespace).first ?? ""
			let size = Double(sizeDescriptor.dropLast()) ?? 1
			if url.isEmpty {
				continue
			}
			if sizeDescriptor.hasSuffix("w"), size >= Self.preferredSrcsetWidth, size < narrowestWideEnough?.size ?? .infinity {
				narrowestWideEnough = (url: url, size: size)
			}
			if size > largest?.size ?? -.infinity {
				largest = (url: url, size: size)
			}
		}

		guard let candidate = narrowestWideEnough ?? largest else {
			return nil
		}
		return String(candidate.url)
	}

	/// Lowercase property names and values from a `style` attribute.
	private func styleProperties(_ style: String?) -> [String: String] {
		guard let style else {
			return [:]
		}
		var properties = [String: String]()
		for declaration in style.split(separator: ";") {
			let nameAndValue = declaration.split(separator: ":", maxSplits: 1)
			guard nameAndValue.count == 2 else {
				continue
			}
			let name = nameAndValue[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			properties[name] = nameAndValue[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		}
		return properties
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
