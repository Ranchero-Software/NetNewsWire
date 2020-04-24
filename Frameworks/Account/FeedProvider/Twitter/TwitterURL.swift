//
//  TwitterURL.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterURL: Codable, TwitterEntity {
	
	let url: String?
	let indices: [Int]?
	let displayURL: String?
	let expandedURL: String?

	enum CodingKeys: String, CodingKey {
		case url = "url"
		case indices = "indices"
		case displayURL = "display_url"
		case expandedURL = "expanded_url"
	}
	
	func renderAsHTML() -> String {
		var html = String()
		if let expandedURL = expandedURL, let displayURL = displayURL {
			html += "<a href=\"\(expandedURL)\">\(displayURL)</a>"
		}
		return html
	}
	
}
