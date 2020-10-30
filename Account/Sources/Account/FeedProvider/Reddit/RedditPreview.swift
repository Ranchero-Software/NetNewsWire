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
	let variants: RedditPreviewImageVariants?

	enum CodingKeys: String, CodingKey {
		case source = "source"
		case variants = "variants"
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

struct RedditPreviewImageVariants: Codable {
	
	let mp4: RedditPreviewImageVariantsMP4?

	enum CodingKeys: String, CodingKey {
		case mp4 = "mp4"
	}
	
}

struct RedditPreviewImageVariantsMP4: Codable {
	
	let source: RedditPreviewImageVariantsMP4Source?

	enum CodingKeys: String, CodingKey {
		case source = "source"
	}
	
}

struct RedditPreviewImageVariantsMP4Source: Codable {
	
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
