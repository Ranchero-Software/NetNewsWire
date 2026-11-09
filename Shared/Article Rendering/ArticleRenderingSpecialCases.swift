//
//  ArticleRenderingSpecialCases.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/25/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSWeb
import Articles

struct ArticleRenderingSpecialCases {

	// Content JavaScript is always disabled for articles from these domains,
	// regardless of the user setting. Subdomains match too.
	private static let domainsWithJavaScriptDisabled = ["slashdot.org", "blog.rust-lang.org"]

	/// True when any of the URL strings (article link, feed URL, feed home page URL)
	/// is on a domain whose article content must render without JavaScript.
	static func shouldDisableJavaScript(urlStrings: [String?]) -> Bool {
		anyURLStringMatchesAnyDomain(urlStrings, domainsWithJavaScriptDisabled)
	}

	@MainActor static func shouldDisableJavaScript(for article: Article) -> Bool {
		shouldDisableJavaScript(urlStrings: [article.link, article.feed?.url, article.feed?.homePageURL])
	}

	private static let feedDomainsWithParagraphsSeparatedByReturns = ["slashdot.org"]
	private static let consecutiveReturnsRegex = try? NSRegularExpression(pattern: "(?:\\r?\\n[ \\t]*){2,}")

	/// Checks the home page too, which catches a feed subscribed through a proxy such as FeedBurner.
	static func insertParagraphTagsIfNeeded(_ html: String, feedURL: String?, homePageURL: String?) -> String {
		guard anyURLStringMatchesAnyDomain([feedURL, homePageURL], feedDomainsWithParagraphsSeparatedByReturns) else {
			return html
		}
		guard html.utf8.contains(UInt8(ascii: "\n")), let consecutiveReturnsRegex else {
			return html
		}

		let range = NSRange(html.startIndex..., in: html)
		return consecutiveReturnsRegex.stringByReplacingMatches(in: html, range: range, withTemplate: "<p>")
	}

	private static let feedDomainsWithStrayLineBreaks = ["macrumors.com"]

	// One or more <br>s right after a tag where a <br> can't appear — between list items,
	// table rows, or table cells. Not after an opening <li>, <td>, or <th>: a <br> there is content.
	private static let strayLineBreaksRegex = try? NSRegularExpression(
		pattern: "(<(?:ul|ol|table|thead|tbody|tfoot|tr)\\b[^>]*>|</(?:li|tr|td|th|thead|tbody|tfoot)>)(?:\\s*<br\\s*/?>)+",
		options: [.caseInsensitive]
	)

	/// MacRumors puts a <br/> after every line of its feed HTML, including inside lists and tables.
	/// In lists each one renders as a blank line. In tables the HTML parser moves them all
	/// to just before the table, leaving a huge gap above it. Remove them before parsing,
	/// while they’re still recognizable.
	/// <https://github.com/Ranchero-Software/NetNewsWire/issues/5498>
	static func removeStrayLineBreaksIfNeeded(_ html: String, feedURL: String?, homePageURL: String?) -> String {
		guard anyURLStringMatchesAnyDomain([feedURL, homePageURL], feedDomainsWithStrayLineBreaks) else {
			return html
		}
		guard html.range(of: "<br", options: .caseInsensitive) != nil, let strayLineBreaksRegex else {
			return html
		}

		let range = NSRange(html.startIndex..., in: html)
		return strayLineBreaksRegex.stringByReplacingMatches(in: html, range: range, withTemplate: "$1")
	}

	private static let feedDomainsWithSmallBodyImages = ["flickr.com"]

	// A Flickr image’s `<img src="…" width="…" height="…"` — the URL up to the size suffix, then the dimensions.
	private static let flickrImageRegex = try? NSRegularExpression(
		pattern: "<img src=\"(https://live\\.staticflickr\\.com/[^\"]+_)[a-z]\\.jpg\" width=\"\\d+\" height=\"\\d+\"",
		options: [.caseInsensitive]
	)

	/// Flickr feeds embed a small copy of the photo (`_m.jpg`, 240 pixels) and list a large copy
	/// (`_b.jpg`, or `_z.jpg` for smaller photos) as the enclosure. Use the enclosure’s copy in the body,
	/// so the enclosure is skipped as a duplicate.
	static func enlargeFlickrImagesIfNeeded(_ html: String, feedURL: String?, attachmentURLs: [String]) -> String {
		guard anyURLStringMatchesAnyDomain([feedURL], feedDomainsWithSmallBodyImages) else {
			return html
		}
		guard !attachmentURLs.isEmpty, html.contains("staticflickr.com"), let flickrImageRegex else {
			return html
		}

		var result = ""
		var remainderStart = html.startIndex
		for match in flickrImageRegex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
			guard let tagRange = Range(match.range, in: html), let prefixRange = Range(match.range(at: 1), in: html) else {
				continue
			}
			let prefix = html[prefixRange]
			guard let largeImageURL = attachmentURLs.first(where: { $0.hasPrefix(prefix) }) else {
				continue
			}
			result += html[remainderStart..<tagRange.lowerBound]
			result += "<img src=\"\(largeImageURL.escapingSpecialXMLCharacters)\""
			remainderStart = tagRange.upperBound
		}
		result += html[remainderStart...]
		return result
	}

	static func filterHTMLIfNeeded(baseURL: String, html: String) -> String {
		var filteredHTML = removeLocationHrefRedirectScripts(html)

		if let url = URL(string: baseURL), isVergeSpecialCase(url) {
			filteredHTML = filterVergeHTML(filteredHTML)
		}

		if shouldDisableJavaScript(urlStrings: [baseURL]) {
			filteredHTML = unwrappingNoscriptTags(filteredHTML)
		}

		return filteredHTML
	}

	// Even with content JavaScript disabled for the page, WebKit’s user agent style sheet
	// still hides <noscript> (display: none). Remove the tags so their content shows
	// (the Rust blog’s charts, for example).
	// <https://github.com/Ranchero-Software/NetNewsWire/issues/5518>
	private static let noscriptTagRegex = try? NSRegularExpression(pattern: "</?noscript\\b[^>]*>", options: [.caseInsensitive])

	static func unwrappingNoscriptTags(_ html: String) -> String {
		guard html.range(of: "<noscript", options: .caseInsensitive) != nil, let noscriptTagRegex else {
			return html
		}

		let range = NSRange(html.startIndex..., in: html)
		return noscriptTagRegex.stringByReplacingMatches(in: html, range: range, withTemplate: "")
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

	// YouTube won’t play an embed whose host page is itself on youtube.com — the
	// embed’s Referer has to identify a third-party client. Articles from YouTube
	// channel feeds link to youtube.com/watch, so they render with NetNewsWire’s
	// site as the base URL instead.
	// <https://github.com/Ranchero-Software/NetNewsWire/issues/4860>
	private static let baseURLForYouTubeArticles = URL(string: "https://netnewswire.com/")

	static func baseURLForRendering(_ url: URL) -> URL {
		if url.isYoutubeURL, let baseURLForYouTubeArticles {
			return baseURLForYouTubeArticles
		}
		return url
	}

	private static let youTubeFlashPlayerPathPrefix = "/v/"
	private static let youTubeEmbedURLPrefix = "https://www.youtube-nocookie.com/embed/"
	private static let youTubeVideoIDCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")

	/// YouTube channel feeds list each video as a dead Flash player URL (youtube.com/v/ID).
	/// Returns the privacy-enhanced embed player URL for the same video.
	static func youTubeEmbedURL(forAttachmentURL urlString: String) -> String? {
		guard let url = URL(string: urlString), url.isYoutubeURL, url.path.hasPrefix(youTubeFlashPlayerPathPrefix) else {
			return nil
		}
		let videoID = url.path.dropFirst(youTubeFlashPlayerPathPrefix.count)
		guard !videoID.isEmpty, videoID.unicodeScalars.allSatisfy({ youTubeVideoIDCharacters.contains($0) }) else {
			return nil
		}
		return youTubeEmbedURLPrefix + videoID
	}

	private static let youTubeVideoIDLength = 11
	private static let youTubeEmbedPaths = ["youtube.com/embed/", "youtube-nocookie.com/embed/"]

	/// True when `body` embeds the YouTube video that the image at `stillImageURL` is a still of.
	/// Substack lists the still as an enclosure, as in `substackcdn.com/image/youtube/w_728,c_limit/VIDEO_ID`.
	/// YouTube’s own stills are like `i.ytimg.com/vi/VIDEO_ID/hqdefault.jpg`.
	static func bodyEmbedsYouTubeVideo(stillImageURL: String, body: String) -> Bool {
		guard let url = URL(string: stillImageURL) else {
			return false
		}
		let possibleVideoIDs = url.pathComponents.filter { pathComponent in
			pathComponent.count == youTubeVideoIDLength && pathComponent.unicodeScalars.allSatisfy { youTubeVideoIDCharacters.contains($0) }
		}
		for videoID in possibleVideoIDs {
			if youTubeEmbedPaths.contains(where: { body.contains($0 + videoID) }) {
				return true
			}
		}
		return false
	}

	private static func anyURLStringMatchesAnyDomain(_ urlStrings: [String?], _ domains: [String]) -> Bool {
		for urlString in urlStrings {
			if let urlString, SpecialCase.urlStringMatchesDomain(urlString, domains) {
				return true
			}
		}
		return false
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

	/// De-sanitize some parts of the HTML that FreshRSS sanitized.
	///
	/// Doing this allows inline footnotes to work, without it they are broken, since they rely on matching `id` and `class` attributes.
	static func desanitizeFreshRSSContent(_ content: String) -> String {
		let classRegex = /(?'open'<[^>]*?)data-sanitized-class(?'close'[^<]*?>)/
		let idRegex = /(?'open'<[^>]*?)data-sanitized-id(?'close'[^<]*?>)/
		return content
			.replacing(classRegex, with: { match in
				match.output.open + "class" + match.output.close
			})
			.replacing(idRegex, with: { match in
				match.output.open + "id" + match.output.close
			})
	}
}
