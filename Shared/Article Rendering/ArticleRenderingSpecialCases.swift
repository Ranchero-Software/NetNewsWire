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
		guard let url = URL(string: baseURL) else {
			return html
		}

		if isVergeSpecialCase(url) {
			return filterVergeHTML(html)
		}

		return html
	}

	static func isVergeSpecialCase(_ baseURL: URL) -> Bool {
		guard let host = baseURL.host() else {
			return false
		}

		return host.lowercased().contains("theverge.com")
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
