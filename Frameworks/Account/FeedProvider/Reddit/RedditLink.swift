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
	let mediaEmbed: RedditMediaEmbed?
	let preview: RedditPreview?
    
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
		case mediaEmbed = "media_embed"
		case preview = "preview"
    }
	
	var createdDate: Date? {
		guard let created = created else { return nil }
		return Date(timeIntervalSince1970: created)
	}
	
	func renderAsHTML() -> String? {
		var html = String()
		if let selfHTML = selfHTML {
			html += selfHTML
		}
		if let urlHTML = renderURLAsHTML() {
			html += urlHTML
		}
		return html
	}

	func renderURLAsHTML() -> String? {
		guard let url = url else { return nil }
		
		if isVideo ?? false {
			guard let fallbackURL = media?.video?.fallbackURL else {
				return nil
			}
			var html = "<video "
			if let previewImageURL = preview?.images?.first?.source?.url {
				html += "poster=\"\(previewImageURL)\" "
			}
			if let width = media?.video?.width, let height = media?.video?.height {
				html += "width=\"\(width)\" height=\"\(height)\" "
			}
			html += "src=\"\(fallbackURL)\"></video>"
			return html
		}
		
		if let imageSource = preview?.images?.first?.source, let imageURL = imageSource.url {
			var html = "<figure><a href=\"\(url)\"><img src=\"\(imageURL)\" "
			if let width = imageSource.width, let height = imageSource.height {
				html += "width=\"\(width)\" height=\"\(height)\" "
			}
			html += "></a></figure>"
			return html
		}
		
		if let mediaEmbedContent = mediaEmbed?.content {
			return mediaEmbedContent
		}
		
		return nil
	}
	
}
