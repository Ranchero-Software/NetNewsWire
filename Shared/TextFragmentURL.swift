//
//  TextFragmentURL.swift
//  NetNewsWire
//
//  Created by Jérôme Meyer on 1/24/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation

/// Utility for creating text fragment URLs.
/// Text fragments allow linking directly to a highlighted portion of a web page.
/// Format: https://example.com/article#:~:text=selected%20text
enum TextFragmentURL {

	/// Creates a text fragment URL from a base URL and selected text.
	/// Returns nil if the URL cannot be created.
	static func url(from baseURL: URL, selectedText: String) -> URL? {
		guard !selectedText.isEmpty else {
			return nil
		}

		// Remove any existing fragment from the URL
		var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
		components?.fragment = nil

		guard var urlString = components?.string else {
			return nil
		}

		// Encode the text for use in a text fragment
		guard let encodedText = encodeTextFragment(selectedText) else {
			return nil
		}

		// Append the text fragment directive
		urlString += "#:~:text=\(encodedText)"

		return URL(string: urlString)
	}

	private static func encodeTextFragment(_ text: String) -> String? {
		// Text fragments require encoding per the spec
		// Special characters that need encoding: & - , =
		// Plus standard percent encoding for non-ASCII and reserved characters

		var allowed = CharacterSet.urlQueryAllowed
		// Remove characters that have special meaning in text fragments
		allowed.remove(charactersIn: "&-,=")

		return text.addingPercentEncoding(withAllowedCharacters: allowed)
	}
}
