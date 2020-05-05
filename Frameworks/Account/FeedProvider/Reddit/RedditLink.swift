//
//  RedditLink.swift
//  Account
//
//  Created by Maurice Parker on 5/4/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RedditLink: Codable {
    
    let kind: String?
	let data: RedditLinkData?
    
    enum CodingKeys: String, CodingKey {
        case kind = "kind"
        case data = "data"
    }
	
}

struct RedditLinkData: Codable {
    
    let title: String?
	let permalink: String?
    let url: String?
    let id: String?
	let selfHTML: String?
	let selfText: String?
	let author: String?
	let created: Double?
	let isVideo: Bool?
	let media: RedditMedia?
    
    enum CodingKeys: String, CodingKey {
        case title = "title"
		case permalink = "permalink"
        case url = "url"
        case id = "id"
		case selfHTML = "selftext_html"
		case selfText = "selftext"
		case author = "author"
		case created = "created_utc"
		case isVideo = "is_video"
		case media = "media"
    }
	
	var createdDate: Date? {
		guard let created = created else { return nil }
		return Date(timeIntervalSince1970: created)
	}
	
	func renderAsHTML() -> String? {
		var html = String()
		if let selfHTML = selfHTML {
			html.append(selfHTML)
		}
		if let urlHTML = renderURLAsHTML() {
			html.append(urlHTML)
		}
		return html
	}

	func renderURLAsHTML() -> String? {
		guard let url = url else { return nil }
		
		if isVideo ?? false {
			guard let fallbackURL = media?.video?.fallbackURL else {
				return nil
			}
			return "<video src=\"\(fallbackURL)\"></video>"
		}
		
		guard url.hasSuffix(".jpg") || url.hasSuffix(".jpeg") || url.hasSuffix(".png") || url.hasSuffix(".gif") else {
			return nil
		}
		
		return "<figure><img src=\"\(url)\"></figure>"
	}
	
}
