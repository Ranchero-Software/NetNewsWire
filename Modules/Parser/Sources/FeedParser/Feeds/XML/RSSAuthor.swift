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

	init(name: String?, url: String?, avatarURL: String?, emailAddress: String?) {
		self.name = name
		self.url = url
		self.avatarURL = avatarURL
		self.emailAddress = emailAddress
	}
	
	/// Use when the actual property is unknown. Guess based on contents of the string. (This is common with RSS.)
	convenience init(singleString: String) {

		if singleString.contains("@") {
			self.init(name: nil, url: nil, avatarURL: nil, emailAddress: singleString)
		} else if singleString.lowercased().hasPrefix("http") {
			self.init(name: nil, url: singleString, avatarURL: nil, emailAddress: nil)
		} else {
			self.init(name: singleString, url: nil, avatarURL: nil, emailAddress: nil)
		}
	}
}
