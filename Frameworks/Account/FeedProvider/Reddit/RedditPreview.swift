//
//  RedditPreview.swift
//  Account
//
//  Created by Maurice Parker on 5/5/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RedditPreview: Codable {

	let images: [RedditPreviewImage]?
	let videoPreview: RedditVideoPreview?
    
    enum CodingKeys: String, CodingKey {
        case images = "images"
		case videoPreview = "reddit_video_preview"
    }
	
}

struct RedditPreviewImage: Codable {
	
	let source: RedditPreviewImageSource?

	enum CodingKeys: String, CodingKey {
		case source = "source"
	}
	
}

struct RedditPreviewImageSource: Codable {
	
	let url: String?
	let width: Int?
	let height: Int?

	enum CodingKeys: String, CodingKey {
		case url = "url"
		case width = "width"
		case height = "height"
	}
	
}

struct RedditVideoPreview: Codable {
	
	let url: String?
	let width: Int?
	let height: Int?

	enum CodingKeys: String, CodingKey {
		case url = "fallback_url"
		case width = "width"
		case height = "height"
	}
	
}
