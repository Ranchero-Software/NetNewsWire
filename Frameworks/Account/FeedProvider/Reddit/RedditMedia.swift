//
//  RedditMedia.swift
//  Account
//
//  Created by Maurice Parker on 5/4/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RedditMedia: Codable {

	let video: RedditVideo?
    
    enum CodingKeys: String, CodingKey {
        case video = "reddit_video"
    }
	
}

struct RedditVideo: Codable {
	
	let fallbackURL: String?
	let hlsURL: String?
	let height: Int?
	let width: Int?
	
	enum CodingKeys: String, CodingKey {
		case fallbackURL = "fallback_url"
		case hlsURL = "hls_url"
		case height = "height"
		case width = "width"
	}
	
}
