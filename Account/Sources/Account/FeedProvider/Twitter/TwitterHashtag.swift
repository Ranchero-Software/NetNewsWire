//
//  TwitterHashtag.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterHashtag: Codable, TwitterEntity {
	
	let text: String?
	let indices: [Int]?

	enum CodingKeys: String, CodingKey {
		case text = "text"
		case indices = "indices"
	}
	
	func renderAsHTML() -> String {
		var html = String()
		if let text = text {
			html += "<a href=\"https://twitter.com/search?q=%23\(text)\">#\(text)</a>"
		}
		return html
	}
}
