//
//  JSONFeedParser.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
import ParserObjC
#endif

// See https://jsonfeed.org/version/1.1

public struct JSONFeedParser {

	struct Key {
		static let version = "version"
		static let items = "items"
		static let title = "title"
		static let homePageURL = "home_page_url"
		static let feedURL = "feed_url"
		static let feedDescription = "description"
		static let nextURL = "next_url"
		static let icon = "icon"
		static let favicon = "favicon"
		static let expired = "expired"
		static let author = "author"
		static let authors = "authors"
		static let name = "name"
		static let url = "url"
		static let avatar = "avatar"
		static let hubs = "hubs"
		static let type = "type"
		static let contentHTML = "content_html"
		static let contentText = "content_text"
		static let externalURL = "external_url"
		static let summary = "summary"
		static let image = "image"
		static let bannerImage = "banner_image"
		static let datePublished = "date_published"
		static let dateModified = "date_modified"
		static let tags = "tags"
		static let uniqueID = "id"
		static let attachments = "attachments"
		static let mimeType = "mime_type"
		static let sizeInBytes = "size_in_bytes"
		static let durationInSeconds = "duration_in_seconds"
		static let language = "language"
	}

	static let jsonFeedVersionMarker = "://jsonfeed.org/version/" // Allow for the mistake of not getting the scheme exactly correct.

	public static func parse(_ parserData: ParserData) throws -> ParsedFeed? {

		guard let d = JSONUtilities.dictionary(with: parserData.data) else {
			throw FeedParserError(.invalidJSON)
		}

		guard let version = d[Key.version] as? String, let _ = version.range(of: JSONFeedParser.jsonFeedVersionMarker) else {
			throw FeedParserError(.jsonFeedVersionNotFound)
		}
		guard let itemsArray = d[Key.items] as? JSONArray else {
			throw FeedParserError(.jsonFeedItemsNotFound)
		}
		guard let title = d[Key.title] as? String else {
			throw FeedParserError(.jsonFeedTitleNotFound)
		}

		let authors = parseAuthors(d)
		let homePageURL = d[Key.homePageURL] as? String
		let feedURL = d[Key.feedURL] as? String ?? parserData.url
		let feedDescription = d[Key.feedDescription] as? String
		let nextURL = d[Key.nextURL] as? String
		let iconURL = d[Key.icon] as? String
		let faviconURL = d[Key.favicon] as? String
		let expired = d[Key.expired] as? Bool ?? false
		let hubs = parseHubs(d)
		let language = d[Key.language] as? String

		let items = parseItems(itemsArray, parserData.url)

		return ParsedFeed(type: .jsonFeed, title: title, homePageURL: homePageURL, feedURL: feedURL, language: language, feedDescription: feedDescription, nextURL: nextURL, iconURL: iconURL, faviconURL: faviconURL, authors: authors, expired: expired, hubs: hubs, items: items)
	}
}

private extension JSONFeedParser {

	static func parseAuthors(_ dictionary: JSONDictionary) -> Set<ParsedAuthor>? {

		if let authorsArray = dictionary[Key.authors] as? JSONArray {
			var authors = Set<ParsedAuthor>()
			for author in authorsArray {
				if let parsedAuthor = parseAuthor(author) {
					authors.insert(parsedAuthor)
				}
			}
			return authors
		}

		guard let authorDictionary = dictionary[Key.author] as? JSONDictionary,
			  let parsedAuthor = parseAuthor(authorDictionary) else {
			return nil
		}

		return Set([parsedAuthor])
	}

	static func parseAuthor(_ dictionary: JSONDictionary) -> ParsedAuthor? {
		let name = dictionary[Key.name] as? String
		let url = dictionary[Key.url] as? String
		let avatar = dictionary[Key.avatar] as? String
		if name == nil && url == nil && avatar == nil {
			return nil
		}
		return ParsedAuthor(name: name, url: url, avatarURL: avatar, emailAddress: nil)
	}

	static func parseHubs(_ dictionary: JSONDictionary) -> Set<ParsedHub>? {

		guard let hubsArray = dictionary[Key.hubs] as? JSONArray else {
			return nil
		}

		let hubs = hubsArray.compactMap { (hubDictionary) -> ParsedHub? in
			guard let hubURL = hubDictionary[Key.url] as? String, let hubType = hubDictionary[Key.type] as? String else {
				return nil
			}
			return ParsedHub(type: hubType, url: hubURL)
		}
		return hubs.isEmpty ? nil : Set(hubs)
	}

	static func parseItems(_ itemsArray: JSONArray, _ feedURL: String) -> Set<ParsedItem> {

		return Set(itemsArray.compactMap { (oneItemDictionary) -> ParsedItem? in
			return parseItem(oneItemDictionary, feedURL)
		})
	}

	static func parseItem(_ itemDictionary: JSONDictionary, _ feedURL: String) -> ParsedItem? {

		guard let uniqueID = parseUniqueID(itemDictionary) else {
			return nil
		}

		let contentHTML = itemDictionary[Key.contentHTML] as? String
		let contentText = itemDictionary[Key.contentText] as? String
		if contentHTML == nil && contentText == nil {
			return nil
		}

		let url = itemDictionary[Key.url] as? String
		let externalURL = itemDictionary[Key.externalURL] as? String
		let title = parseTitle(itemDictionary, feedURL)
		let language = itemDictionary[Key.language] as? String
		let summary = itemDictionary[Key.summary] as? String
		let imageURL = itemDictionary[Key.image] as? String
		let bannerImageURL = itemDictionary[Key.bannerImage] as? String

		let datePublished = parseDate(itemDictionary[Key.datePublished] as? String)
		let dateModified = parseDate(itemDictionary[Key.dateModified] as? String)

		let authors = parseAuthors(itemDictionary)
		var tags: Set<String>? = nil
		if let tagsArray = itemDictionary[Key.tags] as? [String] {
			tags = Set(tagsArray)
		}
		let attachments = parseAttachments(itemDictionary)

		return ParsedItem(syncServiceID: nil, uniqueID: uniqueID, feedURL: feedURL, url: url, externalURL: externalURL, title: title, language: language, contentHTML: contentHTML, contentText: contentText, summary: summary, imageURL: imageURL, bannerImageURL: bannerImageURL, datePublished: datePublished, dateModified: dateModified, authors: authors, tags: tags, attachments: attachments)
	}

	static func parseTitle(_ itemDictionary: JSONDictionary, _ feedURL: String) -> String? {

		guard let title = itemDictionary[Key.title] as? String else {
			return nil
		}

		if isSpecialCaseTitleWithEntitiesFeed(feedURL) {
			return (title as NSString).rsparser_stringByDecodingHTMLEntities()
		}

		return title
	}

	static func isSpecialCaseTitleWithEntitiesFeed(_ feedURL: String) -> Bool {

		// As of 16 Feb. 2018, Kottke’s and Heer’s feeds includes HTML entities in the title elements.
		// If we find more feeds like this, we’ll add them here. If these feeds get fixed, we’ll remove them.

		let lowerFeedURL = feedURL.lowercased()
		let matchStrings = ["kottke.org", "pxlnv.com", "macstories.net", "macobserver.com"]
		for matchString in matchStrings {
			if lowerFeedURL.contains(matchString) {
				return true
			}
		}

		return false
	}

	static func parseUniqueID(_ itemDictionary: JSONDictionary) -> String? {

		if let uniqueID = itemDictionary[Key.uniqueID] as? String {
			return uniqueID // Spec says it must be a string
		}
		// Version 1 spec also says that if it’s a number, even though that’s incorrect, it should be coerced to a string.
		if let uniqueID = itemDictionary[Key.uniqueID] as? Int {
			return "\(uniqueID)"
		}
		if let uniqueID = itemDictionary[Key.uniqueID] as? Double {
			return "\(uniqueID)"
		}
		return nil
	}

	static func parseDate(_ dateString: String?) -> Date? {

		guard let dateString = dateString, !dateString.isEmpty else {
			return nil
		}
		return RSDateWithString(dateString)
	}

	static func parseAttachments(_ itemDictionary: JSONDictionary) -> Set<ParsedAttachment>? {

		guard let attachmentsArray = itemDictionary[Key.attachments] as? JSONArray else {
			return nil
		}
		return Set(attachmentsArray.compactMap { parseAttachment($0) })
	}

	static func parseAttachment(_ attachmentObject: JSONDictionary) -> ParsedAttachment? {

		guard let url = attachmentObject[Key.url] as? String else {
			return nil
		}
		guard let mimeType = attachmentObject[Key.mimeType] as? String else {
			return nil
		}

		let title = attachmentObject[Key.title] as? String
		let sizeInBytes = attachmentObject[Key.sizeInBytes] as? Int
		let durationInSeconds = attachmentObject[Key.durationInSeconds] as? Int

		return ParsedAttachment(url: url, mimeType: mimeType, title: title, sizeInBytes: sizeInBytes, durationInSeconds: durationInSeconds)
	}
}
