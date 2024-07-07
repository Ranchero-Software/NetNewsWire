//
//  ReaderAPIArticle.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ReaderAPIEntryWrapper: Codable, Sendable {

	public let id: String
	public let updated: Int
	public let entries: [ReaderAPIEntry]

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

public struct ReaderAPIEntry: Codable, Sendable {

	public let articleID: String
	public let title: String?
	public let author: String?

	public let publishedTimestamp: Double?
	public let crawledTimestamp: String?
	public let timestampUsec: String?

	public let summary: ReaderAPIArticleSummary
	public let alternates: [ReaderAPIAlternateLocation]?
	public let categories: [String]
	public let origin: ReaderAPIEntryOrigin

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
	}
	
	public func parseDatePublished() -> Date? {
		guard let unixTime = publishedTimestamp else {
			return nil
		}
		return Date(timeIntervalSince1970: unixTime)
	}
	
	public func uniqueID(variant: ReaderAPIVariant) -> String {
		// Should look something like "tag:google.com,2005:reader/item/00058b10ce338909"
		// REGEX feels heavy, I should be able to just split on / and take the last element
		
		guard let idPart =  articleID.components(separatedBy: "/").last else {
			return articleID
		}
		
		guard variant != .theOldReader else {
			return idPart
		}

		// Convert hex representation back to integer and then a string representation
		guard let idNumber = Int(idPart, radix: 16) else {
			return articleID
		}
		
		return String(idNumber, radix: 10, uppercase: false)
	}
}

public struct ReaderAPIArticleSummary: Codable, Sendable {

	public let content: String?
	
	enum CodingKeys: String, CodingKey {
		case content = "content"
	}
}

public struct ReaderAPIAlternateLocation: Codable, Sendable {

	public let url: String?

	enum CodingKeys: String, CodingKey {
		case url = "href"
	}
}

public struct ReaderAPIEntryOrigin: Codable, Sendable {

	public let streamID: String?
	public let title: String?

	enum CodingKeys: String, CodingKey {
		case streamID = "streamId"
		case title = "title"
	}
}
