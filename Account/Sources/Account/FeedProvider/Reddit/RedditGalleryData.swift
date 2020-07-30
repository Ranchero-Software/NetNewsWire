//
//  RedditGalleryData.swift
//  Account
//
//  Created by Maurice Parker on 7/27/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RedditGalleryData: Codable {

	let items: [RedditGalleryDataItem]?
	
	enum CodingKeys: String, CodingKey {
		case items = "items"
	}
	
}

struct RedditGalleryDataItem: Codable {
	
	let mediaID: String?
	
	enum CodingKeys: String, CodingKey {
		case mediaID = "media_id"
	}
	
}
