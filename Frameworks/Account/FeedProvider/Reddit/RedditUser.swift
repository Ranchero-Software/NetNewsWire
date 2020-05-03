//
//  RedditUser.swift
//  Account
//
//  Created by Maurice Parker on 5/3/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RedditUser: Codable {

	let name: String?

	enum CodingKeys: String, CodingKey {
		case name = "name"
	}
	
//	var url: String {
//		return "https://twitter.com/\(screenName ?? "")"
//	}
//	
//	func renderAsHTML() -> String? {
//		var html = String()
//		html += "<div><a href=\"\(url)\">"
//		if let avatarURL = avatarURL {
//			html += "<img class=\"twitterAvatar\" src=\"\(avatarURL)\">"
//		}
//		html += "<span class=\"twitterUsername\">"
//		if let name = name {
//			html += " \(name)"
//		}
//		if let screenName = screenName {
//			html += " @\(screenName)"
//		}
//		html += "</span></a></div>"
//		return html
//	}
	
}
