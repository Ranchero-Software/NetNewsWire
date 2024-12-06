//
//  RSSEnclosure.swift
//
//
//  Created by Brent Simmons on 8/27/24.
//

import Foundation

final class RSSEnclosure {

	var url: String
	var length: Int?
	var mimeType: String?
	var title: String?

	init(url: String) {
		self.url = url
	}
}
