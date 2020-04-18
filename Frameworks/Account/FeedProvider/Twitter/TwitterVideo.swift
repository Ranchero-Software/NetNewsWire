//
//  TwitterVideoInfo.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation


struct TwitterVideo: Codable {
	
	let variants: [Variant]?

	enum CodingKeys: String, CodingKey {
		case variants = "variants"
	}
	
	struct Variant: Codable {
		
		let bitrate: Int?
		let contentType: String?
		let url: String?

		enum CodingKeys: String, CodingKey {
			case bitrate = "bitrate"
			case contentType = "content_type"
			case url = "url"
		}

	}

}
