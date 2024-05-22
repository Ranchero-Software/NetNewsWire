//
//  RSSInJSONParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
import ParserObjC
#endif

// See https://github.com/scripting/Scripting-News/blob/master/rss-in-json/README.md
// Also: http://cyber.harvard.edu/rss/rss.html

public struct RSSInJSONParser {

	public static func parse(_ parserData: ParserData) throws -> ParsedFeed? {

		do {
			guard let parsedObject = try JSONSerialization.jsonObject(with: parserData.data) as? JSONDictionary else {
				throw FeedParserError(.invalidJSON)
			}
			guard let rssObject = parsedObject["rss"] as? JSONDictionary else {
				throw FeedParserError(.rssChannelNotFound)
			}
			guard let channelObject = rssObject["channel"] as? JSONDictionary else {
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
				itemsObject = parsedObject["items"] as? JSONArray
			}
			if itemsObject == nil {
				throw FeedParserError(.rssItemsNotFound)
			}

			let title = channelObject["title"] as? String
			let homePageURL = channelObject["link"] as? String
			let feedURL = parserData.url
			let feedDescription = channelObject["description"] as? String
			let feedLanguage = channelObject["language"] as? String

			let items = parseItems(itemsObject!, parserData.url)

			return ParsedFeed(type: .rssInJSON, title: title, homePageURL: homePageURL, feedURL: feedURL, language: feedLanguage, feedDescription: feedDescription, nextURL: nil, iconURL: nil, faviconURL: nil, authors: nil, expired: false, hubs: nil, items: items)

		}
		catch { throw error }
	}
}

private extension RSSInJSONParser {

	static func parseItems(_ itemsObject: JSONArray, _ feedURL: String) -> Set<ParsedItem> {

		return Set(itemsObject.compactMap{ (oneItemDictionary) -> ParsedItem? in

			return parsedItemWithDictionary(oneItemDictionary, feedURL)
		})
	}

	static func parsedItemWithDictionary(_ itemDictionary: JSONDictionary, _ feedURL: String) -> ParsedItem? {

		let externalURL = itemDictionary["link"] as? String
		let title = itemDictionary["title"] as? String

		var contentHTML = itemDictionary["description"] as? String
		var contentText: String? = nil
		if contentHTML != nil && !(contentHTML!.contains("<")) {
			contentText = contentHTML
			contentHTML = nil
		}
		if contentHTML == nil && contentText == nil && title == nil {
			return nil
		}

		var datePublished: Date? = nil
		if let datePublishedString = itemDictionary["pubDate"] as? String {
			datePublished = RSDateWithString(datePublishedString)
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
			if let authorEmailAddress = authors?.first?.emailAddress {
				s += authorEmailAddress
			}
			if let oneAttachmentURL = attachments?.first?.url {
				s += oneAttachmentURL
			}
			if s.isEmpty {
				// Sheesh. Tough case.
				if let _ = contentHTML {
					s = contentHTML!
				}
				if let _ = contentText {
					s = contentText!
				}
			}
			uniqueID = (s as NSString).rsparser_md5Hash()
		}

		if let uniqueID = uniqueID {
			return ParsedItem(syncServiceID: nil, uniqueID: uniqueID, feedURL: feedURL, url: nil, externalURL: externalURL, title: title, language: nil, contentHTML: contentHTML, contentText: contentText, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: datePublished, dateModified: nil, authors: authors, tags: tags, attachments: attachments)
		}
		return nil
	}

	static func parseAuthors(_ itemDictionary: JSONDictionary) -> Set<ParsedAuthor>? {

		guard let authorEmailAddress = itemDictionary["author"] as? String else {
			return nil
		}
		let parsedAuthor = ParsedAuthor(name: nil, url: nil, avatarURL: nil, emailAddress: authorEmailAddress)
		return Set([parsedAuthor])
	}

	static func parseTags(_ itemDictionary: JSONDictionary) -> Set<String>? {

		if let categoryObject = itemDictionary["category"] as? JSONDictionary {
			if let oneTag = categoryObject["#value"] as? String {
				return Set([oneTag])
			}
			return nil
		}
		else if let categoryArray = itemDictionary["category"] as? JSONArray {
			return Set(categoryArray.compactMap{ $0["#value"] as? String })
		}
		return nil
	}

	static func parseAttachments(_ itemDictionary: JSONDictionary) -> Set<ParsedAttachment>? {

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
		if let attachment = ParsedAttachment(url: attachmentURL, mimeType: type, title: nil, sizeInBytes: attachmentSize, durationInSeconds: nil) {
			return Set([attachment])
		}
		return nil
	}
}
