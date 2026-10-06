//
//  HTMLLink.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

// A single `<a>` element harvested from an HTML document.
// Any field may be nil because HTML can be malformed.

public struct HTMLLink: Sendable {
	public let urlString: String?   // absolute, resolved against the document's base URL
	public let text: String?        // inner text, trimmed
	public let title: String?       // title attribute

	public init(urlString: String?, text: String?, title: String?) {
		self.urlString = urlString
		self.text = text
		self.title = title
	}
}
