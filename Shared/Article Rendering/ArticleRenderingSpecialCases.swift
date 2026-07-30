//
//  ArticleRenderingSpecialCases.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/25/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation

struct ArticleRenderingSpecialCases {

	static func filterHTMLIfNeeded(baseURL: String, html: String) -> String {
		var filteredHTML = removeLocationHrefRedirectScripts(html)

		if let url = URL(string: baseURL), isVergeSpecialCase(url) {
			filteredHTML = filterVergeHTML(filteredHTML)
		}

		return filteredHTML
	}

	// Matches a `<script>` that assigns to `location.href` — `location.href =` but not `==`
	// (a comparison) or a read like `location.href.includes(…)`.
	private static let redirectScriptRegex = try? NSRegularExpression(
		pattern: "<script[^>]*>[^<]*location\\.href\\s*=(?!=)[^<]*</script>",
		options: [.caseInsensitive]
	)

	// Remove any `<script>location.href='…'</script>`
	// <https://github.com/Ranchero-Software/NetNewsWire/issues/4150>
	static func removeLocationHrefRedirectScripts(_ html: String) -> String {
		guard html.contains("location.href"), let redirectScriptRegex else {
			return html
		}

		let range = NSRange(html.startIndex..., in: html)
		return redirectScriptRegex.stringByReplacingMatches(in: html, range: range, withTemplate: "")
	}

	// Some feeds embed an entire HTML document as item content. Rendered inside
	// the article template, the stray <html>/<body> attributes get merged onto
	// the page's real elements, clobbering the theme. Render only the body fragment.
	// <https://github.com/Ranchero-Software/NetNewsWire/issues/3008>
	static func extractBodyFragmentIfNeeded(_ html: String) -> String {
		guard html.range(of: "<body", options: .caseInsensitive) != nil ||
			  html.range(of: "<html", options: .caseInsensitive) != nil ||
			  html.range(of: "<!doctype", options: .caseInsensitive) != nil else {
			return html
		}

		if let fragment = bodyFragment(html) {
			return fragment
		}
		return removingDocumentWrapper(html)
	}

	static func isVergeSpecialCase(_ baseURL: URL) -> Bool {
		guard let host = baseURL.host() else {
			return false
		}

		return host.lowercased().contains("theverge.com")
	}

	// The content between a real <body …> tag and </body> (or the end of the string).
	// Returns nil when there's no body tag.
	private static func bodyFragment(_ html: String) -> String? {
		guard let bodyOpen = rangeOfTag("<body", in: html, startingAt: html.startIndex) else {
			return nil
		}
		guard let tagClose = html.range(of: ">", options: [], range: bodyOpen.upperBound..<html.endIndex) else {
			return nil
		}
		let contentStart = tagClose.upperBound
		let contentEnd = rangeOfTag("</body", in: html, startingAt: contentStart)?.lowerBound ?? html.endIndex
		return String(html[contentStart..<contentEnd])
	}

	// A document with <html>/<head> but no <body> tag: remove the wrapper markup, keep the rest.
	private static func removingDocumentWrapper(_ html: String) -> String {
		var s = html

		if let doctype = s.range(of: "<!doctype", options: .caseInsensitive),
		   let closeBracket = s.range(of: ">", options: [], range: doctype.lowerBound..<s.endIndex) {
			s.removeSubrange(doctype.lowerBound..<closeBracket.upperBound)
		}

		if let headOpen = rangeOfTag("<head", in: s, startingAt: s.startIndex),
		   let headClose = rangeOfTag("</head", in: s, startingAt: headOpen.upperBound),
		   let closeBracket = s.range(of: ">", options: [], range: headClose.lowerBound..<s.endIndex) {
			s.removeSubrange(headOpen.lowerBound..<closeBracket.upperBound)
		}

		if let htmlOpen = rangeOfTag("<html", in: s, startingAt: s.startIndex),
		   let closeBracket = s.range(of: ">", options: [], range: htmlOpen.lowerBound..<s.endIndex) {
			s.removeSubrange(htmlOpen.lowerBound..<closeBracket.upperBound)
		}

		if let htmlClose = rangeOfTag("</html", in: s, startingAt: s.startIndex),
		   let closeBracket = s.range(of: ">", options: [], range: htmlClose.lowerBound..<s.endIndex) {
			s.removeSubrange(htmlClose.lowerBound..<closeBracket.upperBound)
		}

		return s
	}

	// Case-insensitive range of a real tag — "<head" must not match "<header".
	private static func rangeOfTag(_ tag: String, in html: String, startingAt start: String.Index) -> Range<String.Index>? {
		var searchStart = start
		while let range = html.range(of: tag, options: .caseInsensitive, range: searchStart..<html.endIndex) {
			if range.upperBound == html.endIndex {
				return range
			}
			let next = html[range.upperBound]
			if next == ">" || next == "/" || next.isWhitespace {
				return range
			}
			searchStart = range.upperBound
		}
		return nil
	}

	static func filterVergeHTML(_ html: String) -> String {
		var filteredHTML = html

		// Right curly single quote
		filteredHTML = filteredHTML.replacingOccurrences(of: "â€™", with: "’")
		filteredHTML = filteredHTML.replacingOccurrences(of: "&acirc;&#128;&#153;", with: "’")

		// Left curly double quote
		filteredHTML = filteredHTML.replacingOccurrences(of: "â€œ", with: "“")
		filteredHTML = filteredHTML.replacingOccurrences(of: "â&#128;&#156;", with: "“")
		filteredHTML = filteredHTML.replacingOccurrences(of: "&acirc;&#128;&#156;", with: "“")

		// Right curly double quote
		filteredHTML = filteredHTML.replacingOccurrences(of: "â€", with: "”")
		filteredHTML = filteredHTML.replacingOccurrences(of: "â&#128;&#157;", with: "”")
		filteredHTML = filteredHTML.replacingOccurrences(of: "&acirc;&#128;&#157;", with: "”")

		// Em dash
		filteredHTML = filteredHTML.replacingOccurrences(of: "â€”", with: "—")
		filteredHTML = filteredHTML.replacingOccurrences(of: "&acirc;&#128;&#148;", with: "—")

		filteredHTML = filteredHTML.replacingOccurrences(of: "Â", with: "")
		filteredHTML = filteredHTML.replacingOccurrences(of: "&Acirc;&nbsp;", with: "")

		filteredHTML = filteredHTML.replacingOccurrences(of: " &amp;hellip;", with: "…")
		filteredHTML = filteredHTML.replacingOccurrences(of: "&amp;hellip;", with: "…")

		return filteredHTML
	}
}
