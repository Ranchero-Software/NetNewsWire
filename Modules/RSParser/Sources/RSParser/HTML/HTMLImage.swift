//
//  HTMLImage.swift
//  RSParser
//
//  Created by Brent Simmons on 10/25/26.
//

/// An `<img>` element parsed from an HTML document.
/// `width` and `height` are the declared pixel dimensions, nil when absent or not in pixels.
public struct HTMLImage: Sendable, Equatable {

	public let urlString: String // absolute, resolved against the document’s base URL
	public let width: Int?
	public let height: Int?

	public init(urlString: String, width: Int?, height: Int?) {
		self.urlString = urlString
		self.width = width
		self.height = height
	}
}
