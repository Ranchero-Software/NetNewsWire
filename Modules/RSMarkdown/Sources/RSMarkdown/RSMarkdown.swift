//
//  RSMarkdown.swift
//  RSMarkdown
//
//  Created by Brent Simmons on 10/7/25.
//

import Foundation
import Tidemark

public struct RSMarkdown {

	/// Converts Markdown text to HTML.
	/// Returns nil on empty input or error.
	public static func markdownToHTML(_ markdown: String) -> String? {
		guard let cResult = markdown.withCString({ cString in
			md_markdown_to_html(cString, strlen(cString))
		}) else {
			return nil
		}
		let result = String(cString: cResult)
		free(cResult)
		return result
	}
}
