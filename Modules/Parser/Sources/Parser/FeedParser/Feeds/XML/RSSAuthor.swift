//
//  RSSAuthor.swift
//
//
//  Created by Brent Simmons on 8/27/24.
//

import Foundation

final class RSSAuthor {

	var name: String?
	var url: String?
	var avatarURL: String?
	var emailAddress: String?

	init(name: String? = nil, url: String? = nil, avatarURL: String? = nil, emailAddress: String? = nil) {
		self.name = name
		self.url = url
		self.avatarURL = avatarURL
		self.emailAddress = emailAddress
	}

	/// Use when the actual property is unknown. Guess based on contents of the string. (This is common with RSS.)
	convenience init(singleString: String) {

		if singleString.contains("@") {
			self.init(emailAddress: singleString)
		} else if singleString.lowercased().hasPrefix("http") {
			self.init(url: singleString)
		} else {
			self.init(name: singleString)
		}
	}

	func isEmpty() -> Bool {

		name == nil && url == nil && avatarURL == nil && emailAddress == nil
	}
}
