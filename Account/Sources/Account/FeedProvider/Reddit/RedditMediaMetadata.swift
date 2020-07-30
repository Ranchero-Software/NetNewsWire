//
//  RedditMediaMetadata.swift
//  Account
//
//  Created by Maurice Parker on 7/27/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RedditMediaMetadata: Codable {

	let image: RedditMediaMetadataS?
	
	enum CodingKeys: String, CodingKey {
		case image = "s"
	}
	
}

struct RedditMediaMetadataS: Codable {
	
	let url: String?
	let height: Int?
	let width: Int?
	
	enum CodingKeys: String, CodingKey {
		case url = "u"
		case height = "y"
		case width = "x"
	}
	
}
