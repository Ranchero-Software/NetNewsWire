//
//  TwitterMedia.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterMedia: Codable {
	
	let idStr: String?
	let indices: [Int]?
	let mediaURL: String?
	let httpsMediaURL: String?
	let url: String?
	let displayURL: String?
	let type: String?

	enum CodingKeys: String, CodingKey {
		case idStr = "idStr"
		case indices = "indices"
		case mediaURL = "media_url"
		case httpsMediaURL = "media_url_https"
		case url = "url"
		case displayURL = "display_url"
		case type = "type"
	}
	
	func renderAsHTML() -> String {
		var html = String()
		
		switch type {
		case "photo":
			if let url = url {
				html += "<a href=\"\(url)\">"
				html += renderPhotoAsHTML()
				html += "</a>"
			}
		default:
			return ""
		}
		
		return html
	}
	
}

private extension TwitterMedia {

	func renderPhotoAsHTML() -> String {
		if let httpsMediaURL = httpsMediaURL {
			return "<img src=\"\(httpsMediaURL)\">"
		}
		if let mediaURL = mediaURL {
			return "<img src=\"\(mediaURL)\">"
		}
		return ""
	}
	
}
