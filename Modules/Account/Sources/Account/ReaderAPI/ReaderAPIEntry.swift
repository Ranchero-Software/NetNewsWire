//
//  ReaderAPIArticle.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSCore

struct ReaderAPIEntryWrapper: Codable, Sendable {
	let id: String
	let updated: Int
	let entries: [ReaderAPIEntry]

	enum CodingKeys: String, CodingKey {
		case id = "id"
		case updated = "updated"
		case entries = "items"
	}
}

/* {
"id": "tag:google.com,2005:reader/item/00058a3b5197197b",
"crawlTimeMsec": "1559362260113",
"timestampUsec": "1559362260113787",
"published": 1554845280,
"title": "",
"summary": {
"content": "\n<p>Found an old screenshot of NetNewsWire 1.0 for iPhone!</p>\n\n<p><img src=\"https://nnw.ranchero.com/uploads/2019/c07c0574b1.jpg\" alt=\"Netnewswire 1.0 for iPhone screenshot showing the list of feeds.\" title=\"NewsGator got renamed to Sitrion, years later, and then renamed again as Limeade.\" border=\"0\" width=\"260\" height=\"320\"></p>\n"
},
"alternate": [
{
"href": "https://nnw.ranchero.com/2019/04/09/found-an-old.html"
}
],
"categories": [
"user/-/state/com.google/reading-list",
"user/-/label/Uncategorized"
],
"origin": {
"streamId": "feed/130",
"title": "NetNewsWire"
}
}
*/
struct ReaderAPIEntry: Codable, Sendable {
	let articleID: String
	let title: String?
	let author: String?

	let publishedTimestamp: Double?
	let crawledTimestamp: String?
	let timestampUsec: String?

	let summary: ReaderAPIArticleSummary
	let alternates: [ReaderAPIAlternateLocation]?
	let categories: [String]
	let origin: ReaderAPIEntryOrigin
	let enclosures: [ReaderAPIEnclosure]?

	var attachments: [ParsedAttachment]? {
		let attachments = enclosures?.compactMap { $0.parsedAttachment } ?? []
		return attachments.isEmpty ? nil : attachments
	}

	var imageURL: String? {
		enclosures?.first { $0.isImage }?.url
	}

	enum CodingKeys: String, CodingKey {
		case articleID = "id"
		case title = "title"
		case author = "author"
		case summary = "summary"
		case alternates = "alternate"
		case categories = "categories"
		case publishedTimestamp = "published"
		case crawledTimestamp = "crawlTimeMsec"
		case origin = "origin"
		case timestampUsec = "timestampUsec"
		case enclosures = "enclosure"
	}

	func parseDatePublished() -> Date? {
		guard let unixTime = publishedTimestamp else {
			return nil
		}
		return Date(timeIntervalSince1970: unixTime)
	}

	func uniqueID(variant: ReaderAPIVariant) -> String {
		// Should look something like "tag:google.com,2005:reader/item/00058b10ce338909"
		// REGEX feels heavy, I should be able to just split on / and take the last element

		guard let idPart =  articleID.components(separatedBy: "/").last else {
			return articleID
		}

		guard variant != .theOldReader else {
			return idPart
		}

		// Convert hex representation back to integer and then a string representation.
		// Parse unsigned so a high-bit ID doesn't overflow, then reinterpret the bit
		// pattern as signed — the two's-complement form itemIDParameter re-encodes.
		guard let idNumber = UInt64(idPart, radix: 16) else {
			return articleID
		}

		return String(Int64(bitPattern: idNumber))
	}

}

struct ReaderAPIArticleSummary: Codable, Sendable {
	let content: String?

	enum CodingKeys: String, CodingKey {
		case content
	}
}

struct ReaderAPIAlternateLocation: Codable, Sendable {
	let url: String?

	enum CodingKeys: String, CodingKey {
		case url = "href"
	}
}

/// `type` is a MIME type, or a bare `image`, `audio`, or `video` (FreshRSS).
struct ReaderAPIEnclosure: Codable, Sendable {
	let url: String?
	let type: String?
	let length: Int?

	var parsedAttachment: ParsedAttachment? {
		guard let url else {
			return nil
		}
		return ParsedAttachment(url: url, mimeType: mimeType, title: nil, sizeInBytes: sizeInBytes, durationInSeconds: nil, width: nil, height: nil, medium: medium)
	}

	var isImage: Bool {
		medium == .image || mimeType?.lowercased().hasPrefix("image/") == true
	}

	enum CodingKeys: String, CodingKey {
		case url = "href"
		case type
		case length
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		url = try? container.decodeIfPresent(String.self, forKey: .url)
		type = try? container.decodeIfPresent(String.self, forKey: .type)
		if let length = try? container.decodeIfPresent(Int.self, forKey: .length) {
			self.length = length
		} else if let lengthString = try? container.decodeIfPresent(String.self, forKey: .length) {
			self.length = Int(lengthString)
		} else {
			self.length = nil
		}
	}
}

private extension ReaderAPIEnclosure {

	var sizeInBytes: Int? {
		guard let length, length > 0 else {
			return nil
		}
		return length
	}

	var mimeType: String? {
		guard let type, type.contains("/") else {
			return nil
		}
		return type
	}

	var medium: ParsedAttachment.Medium? {
		guard mimeType == nil else {
			return nil
		}
		return ParsedAttachment.Medium(mediaRSSValue: type)
	}
}

struct ReaderAPIEntryOrigin: Codable, Sendable {
	let streamId: String?
	let title: String?

	enum CodingKeys: String, CodingKey {
		case streamId
		case title
	}
}
