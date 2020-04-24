//
//  TwitterExtendedEntities.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterExtendedEntities: Codable {
	
	let medias: [TwitterExtendedMedia]?

	enum CodingKeys: String, CodingKey {
		case medias = "media"
	}
	
	func renderAsHTML() -> String {
		var html = String()
		if let medias = medias {
			for media in medias {
				html += media.renderAsHTML()
			}
		}
		return html
	}
}
