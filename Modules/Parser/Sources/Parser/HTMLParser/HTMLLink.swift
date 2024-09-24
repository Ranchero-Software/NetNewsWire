//
//  HTMLLink.swift
//
//
//  Created by Brent Simmons on 9/21/24.
//

import Foundation

public final class HTMLLink {

	public var urlString: String? // Absolute URL string
	public var text: String?
	public var title: String? // Title attribute inside anchor tag

	init(urlString: String? = nil, text: String? = nil, title: String? = nil) {

		self.urlString = urlString
		self.text = text
		self.title = title
	}
}
