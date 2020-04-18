//
//  TwitterStatus.swift
//  Account
//
//  Created by Maurice Parker on 4/16/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

final class TwitterStatus: Codable {

	let createdAt: Date?
	let idStr: String?
	let fullText: String?
	let displayTextRange: [Int]?
	let user: TwitterUser?
	let truncated: Bool?
	let retweeted: Bool?
	let retweetedStatus: TwitterStatus?
	let quotedStatus: TwitterStatus?
	let entities: TwitterEntities?
	let extendedEntities: TwitterExtendedEntities?
	
	enum CodingKeys: String, CodingKey {
		case createdAt = "created_at"
		case idStr = "id_str"
		case fullText = "full_text"
		case displayTextRange = "display_text_range"
		case user = "user"
		case truncated = "truncated"
		case retweeted = "retweeted"
		case retweetedStatus = "retweeted_status"
		case quotedStatus = "quoted_status"
		case entities = "entities"
		case extendedEntities = "extended_entities"
	}
	
	var url: String? {
		guard let userURL = user?.url, let idStr = idStr else { return nil }
		return "\(userURL)/status/\(idStr)"
	}
	
	var displayText: String? {
		if let text = fullText, let displayRange = displayTextRange, displayRange.count > 1,
			let startIndex = text.index(text.startIndex, offsetBy: displayRange[0], limitedBy: text.endIndex),
			let endIndex = text.index(text.startIndex, offsetBy: displayRange[1], limitedBy: text.endIndex) {
				return String(text[startIndex..<endIndex])
		} else {
			return fullText
		}
	}
	
	func renderAsText() -> String? {
		let statusToRender = retweetedStatus != nil ? retweetedStatus! : self
		return statusToRender.displayText
	}
	
	func renderAsHTML(topLevel: Bool = true) -> String {
		if let retweetedStatus = retweetedStatus {
			return renderAsRetweetHTML(retweetedStatus, topLevel: topLevel)
		}
		if let quotedStatus = quotedStatus {
			return renderAsQuoteHTML(quotedStatus, topLevel: topLevel)
		}
		return renderAsOriginalHTML(topLevel: topLevel)
	}
	
	func renderAsTweetHTML(_ status: TwitterStatus, topLevel: Bool) -> String {
		var html = "<div>\(status.displayText ?? "")</div>"
		
		if !topLevel, let createdAt = status.createdAt {
			let dateFormatter = DateFormatter()
			dateFormatter.dateStyle = .medium
			dateFormatter.timeStyle = .short
			html += "<div class=\"twitterTimestamp\">\(dateFormatter.string(from: createdAt))</div>"
		}
		
		return html
	}
	
	func renderAsOriginalHTML(topLevel: Bool) -> String {
		var html = renderAsTweetHTML(self, topLevel: topLevel)
		if topLevel {
			html += extendedEntities?.renderAsHTML() ?? ""
		}
		return html
	}
	
	func renderAsRetweetHTML(_ status: TwitterStatus, topLevel: Bool) -> String {
		var html = "<blockquote>"
		if let userHTML = status.user?.renderAsHTML() {
			html += userHTML
		}
		html += status.renderAsHTML(topLevel: false)
		html += "</blockquote>"
		if topLevel {
			html += status.extendedEntities?.renderAsHTML() ?? ""
		}
		return html
	}
	
	func renderAsQuoteHTML(_ quotedStatus: TwitterStatus, topLevel: Bool) -> String {
		var html = String()
		html += renderAsTweetHTML(self, topLevel: topLevel)
		html += "<blockquote>"
		if let userHTML = quotedStatus.user?.renderAsHTML() {
			html += userHTML
		}
		html += quotedStatus.renderAsHTML(topLevel: false)
		html += "</blockquote>"
		html += self.extendedEntities?.renderAsHTML() ?? ""
		if topLevel {
			html += quotedStatus.extendedEntities?.renderAsHTML() ?? ""
		}
		return html
	}
	
}
