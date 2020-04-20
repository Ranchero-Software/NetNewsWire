//
//  TwitterMention.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterMention: Codable, TwitterEntity {
	
	let name: String?
	let indices: [Int]?
	let screenName: String?
	let idStr: String?
	
	enum CodingKeys: String, CodingKey {
		case name = "url"
		case indices = "indices"
		case screenName = "screen_name"
		case idStr = "idStr"
	}
	
	func renderAsHTML() -> String {
		var html = String()
		if let screenName = screenName {
			html += "<a href=\"https://twitter.com/\(screenName)\">@\(screenName)</a>"
		}
		return html
	}
	
}
