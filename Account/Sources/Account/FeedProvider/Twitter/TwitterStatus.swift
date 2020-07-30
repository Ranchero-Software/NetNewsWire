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
	
}

private extension TwitterStatus {
	
	var displayText: String? {
		if let text = fullText, let displayRange = displayTextRange, displayRange.count > 1,
			let startIndex = text.index(text.startIndex, offsetBy: displayRange[0], limitedBy: text.endIndex),
			let endIndex = text.index(text.startIndex, offsetBy: displayRange[1], limitedBy: text.endIndex) {
				return String(text[startIndex..<endIndex])
		} else {
			return fullText
		}
	}
	
	var displayHTML: String? {
		if let text = fullText, let displayRange = displayTextRange, displayRange.count > 1, let entities = entities?.combineAndSort() {
			
			let displayStartIndex = text.index(text.startIndex, offsetBy: displayRange[0], limitedBy: text.endIndex) ?? text.startIndex
			let displayEndIndex = text.index(text.startIndex, offsetBy: displayRange[1], limitedBy: text.endIndex) ?? text.endIndex

			var html = String()
			var prevIndex = displayStartIndex
			var emojiOffset = 0
			
			for entity in entities {
				
				// The twitter indices are messed up by emoji with more than one scalar, we are going to adjust for that here.
				let emojiEndIndex = text.index(text.startIndex, offsetBy: entity.endIndex, limitedBy: text.endIndex) ?? text.endIndex
				if prevIndex < emojiEndIndex {
					let emojis = String(text[prevIndex..<emojiEndIndex]).emojis
					for emoji in emojis {
						emojiOffset += emoji.unicodeScalars.count - 1
					}
				}
				
				let offsetStartIndex = entity.startIndex - emojiOffset
				let offsetEndIndex = entity.endIndex - emojiOffset
				
				let entityStartIndex = text.index(text.startIndex, offsetBy: offsetStartIndex, limitedBy: text.endIndex) ?? text.startIndex
				let entityEndIndex = text.index(text.startIndex, offsetBy: offsetEndIndex, limitedBy: text.endIndex) ?? text.endIndex
					
				if prevIndex < entityStartIndex {
					html += String(text[prevIndex..<entityStartIndex]).replacingOccurrences(of: "\n", with: "<br>")
				}
				
				// We drop off any URL which is just pointing to the quoted status.  It is redundant.
				if let twitterURL = entity as? TwitterURL, let expandedURL = twitterURL.expandedURL, let quotedURL = quotedStatus?.url {
					if expandedURL.caseInsensitiveCompare(quotedURL) != .orderedSame {
						html += entity.renderAsHTML()
					}
				} else {
					html += entity.renderAsHTML()
				}
				
				prevIndex = entityEndIndex

			}
			
			if prevIndex < displayEndIndex {
				html += String(text[prevIndex..<displayEndIndex])
			}
			
			return html
		} else {
			return displayText
		}
	}
	
	func renderAsTweetHTML(_ status: TwitterStatus, topLevel: Bool) -> String {
		var html = "<div>\(status.displayHTML ?? "")</div>"
		
		if !topLevel, let createdAt = status.createdAt, let url = status.url {
			let dateFormatter = DateFormatter()
			dateFormatter.dateStyle = .medium
			dateFormatter.timeStyle = .short
			html += "<a href=\"\(url)\" class=\"twitterTimestamp\">\(dateFormatter.string(from: createdAt))</a>"
		}
		
		return html
	}
	
	func renderAsOriginalHTML(topLevel: Bool) -> String {
		var html = renderAsTweetHTML(self, topLevel: topLevel)
		if topLevel {
			html += extendedEntities?.renderAsHTML() ?? ""
			html += retweetedStatus?.extendedEntities?.renderAsHTML() ?? ""
			html += quotedStatus?.extendedEntities?.renderAsHTML() ?? ""
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
			html += status.retweetedStatus?.extendedEntities?.renderAsHTML() ?? ""
			html += status.quotedStatus?.extendedEntities?.renderAsHTML() ?? ""
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
		if topLevel {
			html += quotedStatus.extendedEntities?.renderAsHTML() ?? ""
			html += quotedStatus.retweetedStatus?.extendedEntities?.renderAsHTML() ?? ""
			html += quotedStatus.quotedStatus?.extendedEntities?.renderAsHTML() ?? ""
		}
		return html
	}
	
}
