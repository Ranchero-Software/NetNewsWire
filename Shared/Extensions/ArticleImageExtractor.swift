//
//  ArticleImageExtractor.swift
//  NetNewsWire
//
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles

@MainActor
extension Article {

	/// Returns the article's `imageURL`, or the first image found in its HTML or text content.
	func extractFirstImageURL() -> URL? {
		if let imageURL = self.imageURL {
			return imageURL
		}
		if let html = contentHTML ?? summary {
			return extractFirstImageFromHTML(html)
		}
		if let text = contentText ?? summary {
			return extractFirstImageFromText(text)
		}
		return nil
	}

	private func extractFirstImageFromHTML(_ html: String) -> URL? {
		let pattern = "<img[^>]+src=[\"']([^\"'<>]+)[\"']"

		guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
			  let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: html.utf16.count)) else {
			return nil
		}

		if match.numberOfRanges > 1 {
			let range = match.range(at: 1)
			if let swiftRange = Range(range, in: html) {
				return URL(string: String(html[swiftRange]))
			}
		}

		return nil
	}

	private func extractFirstImageFromText(_ text: String) -> URL? {
		let pattern = "(https?://[^\\s<>]+\\.(?:jpg|jpeg|png|gif|webp|bmp)(?:\\?[^\\s<>]*)?)"

		guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
			  let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) else {
			return nil
		}

		if let swiftRange = Range(match.range, in: text) {
			return URL(string: String(text[swiftRange]))
		}

		return nil
	}
}
