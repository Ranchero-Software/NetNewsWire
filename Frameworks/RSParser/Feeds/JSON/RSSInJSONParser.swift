//
//  RSSInJSONParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// See https://github.com/scripting/Scripting-News/blob/master/rss-in-json/README.md
// Also: http://cyber.harvard.edu/rss/rss.html

public struct RSSInJSONParser {

	public static func parse(parserData: ParserData) throws -> ParsedFeed? {

		do {
			let parsedObject = try JSONSerialization.jsonObject(with: parserData.data)

			guard let channelObject = parsedObject["channel"] as? JSONDictionary else {
				throw FeedParserError(.rssChannelNotFound)
			}

			// I’d bet money that in practice the items array won’t always appear correctly inside the channel object.
			// I’d also bet that sometimes it gets called "items" instead of "item".
			var itemsObject = channelObject["item"] as? JSONArray
			if itemsObject == nil {
				itemsObject = parsedObject["item"] as? JSONArray
			}
			if itemsObject == nil {
				itemsObject = channelObject["items"] as? JSONArray
			}
			if itemsObject == nil {
				itemsObject == parsedObject["items"] as? JSONArray
			}
			if itemsObject == nil {
				throw FeedParserError(.rssItemsNotFound)
			}

			let title = channelObject["title"] as? String
			let homePageURL = channelObject["link"] as? String
			let feedURL = parserData.url
			let feedDescription = channelObject["description"] as? String

			let items = parseItems(itemsObject)

			return ParsedFeed(type: .rssInJSON, title: title, homePageURL: homePageURL, feedURL: feedURL, feedDescription: feedDescription, nextURL: nil, iconURL: nil, faviconURL: nil, authors: nil, expired: false, hubs: nil, items: items)

		}
		catch { throw error }
	}
}

private extension RSSInJSONParser {

	static func parseItems(_ itemsObject: JSONArray) -> [ParsedItem] {

		return itemsObject.flatMap{ (oneItemDictionary) -> ParsedItem in

			return parsedItemWithDictionary(oneItemDictionary)
		}
	}

	static func parsedItemWithDictionary(_ JSONDictionary: itemDictionary) -> ParsedItem? {

		let externalURL = itemDictionary["link"] as? String
		let title = itemDictionary["title"] as? String

		var contentHTML = itemDictionary["description"] as? String
		var contentText = nil
		if contentHTML != nil && !(contentHTML!.contains("<")) {
			contentText = contentHTML
			contentHTML = nil
		}
		if contentHTML == nil && contentText == nil && title == nil {
			return nil
		}

		var datePublished: Date = nil
		if let datePublishedString = itemDictionary["pubDate"] as? String {
			datePublished = RSDateWithString(datePublishedString as NSString)
		}

		let authors = parseAuthors(itemDictionary)
		let tags = parseTags(itemDictionary)
		let attachments = parseAttachments(itemDictionary)

		var uniqueID: String? = itemDictionary["guid"] as? String
		if uniqueID == nil {

			// Calculate a uniqueID based on a combination of non-empty elements. Then hash the result.
			// Items should have guids. When they don't, re-runs are very likely
			// because there's no other 100% reliable way to determine identity.
			// This calculated uniqueID is valid only for this particular feed. (Just like ids in JSON Feed.)

			var s = ""
			if let datePublished = datePublished {
				s += "\(datePublished.timeIntervalSince1970)"
			}
			if let title = title {
				s += title
			}
			if let externalURL = externalURL {
				s += externalURL
			}
			if let authorEmailAddress = authorEmailAddress {
				s += authorEmailAddress
			}
			if let oneAttachmentURL = attachments?.first?.url {
				s += oneAttachmentURL
			}
			if s.isEmpty {
				// Sheesh. Tough case.
				if contentHTML != nil {
					s = contentHTML
				}
				if contentText != nil {
					s = contentText
				}
			}
			uniqueID = (s as NSString).rsxml_md5HashString()
		}

		return ParsedItem(uniqueID: uniqueID, url: nil, externalURL: externalURL, title: title, contentHTML: contentHTML, contentText: contentText, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: datePublished, dateModified: nil, authors: authors, tags: tags, attachments: attachments)
	}

	static func parseAuthors(_ itemDictionary: JSONDictionary) -> [ParsedAuthor]? {

		guard let authorEmailAddress = itemDictionary["author"] as? String else {
			return nil
		}
		let parsedAuthor = ParsedAuthor(name: nil, url: nil, avatarURL: nil, emailAddress: authorEmailAddress)
		return [parsedAuthor]
	}

	static func parseTags(_ itemDictionary: JSONDictionary) -> [String]? {

		if let categoryObject = itemDictionary["category"] as? JSONDictionary {
			return categoryObject["#value"]
		}
		else if let categoryArray = itemDictionary["category"] as? JSONArray {
			return categoryArray.flatMap{ (categoryObject) in
				return categoryObject["#value"]
			}
		}
		return nil
	}

	static func parseAttachments(_ itemDictionary: JSONDictionary) -> [ParsedAttachment]? {

		guard let enclosureObject = itemDictionary["enclosure"] as? JSONDictionary else {
			return nil
		}
		guard let attachmentURL = enclosureObject["url"] as? String else {
			return nil
		}

		var attachmentSize = enclosureObject["length"] as? Int
		if attachmentSize == nil {
			if let attachmentSizeString = enclosureObject["length"] as? String {
				attachmentSize = (attachmentSizeString as NSString).integerValue
			}
		}

		let type = enclosureObject["type"] as? String
		let oneAttachment = ParsedAttachment(url: attachmentURL, mimeType: type, title: nil, sizeInBytes: attachmentSize, durationInSeconds: nil)
		return [oneAttachment]
	}
}
