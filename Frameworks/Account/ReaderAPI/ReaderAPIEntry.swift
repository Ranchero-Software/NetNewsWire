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

struct ReaderAPIEntryWrapper: Codable {
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
struct ReaderAPIEntry: Codable {

	let articleID: String
	let title: String?

	let publishedTimestamp: Double?
	let crawledTimestamp: String?
	let timestampUsec: String?
	
	let summary: ReaderAPIArticleSummary
	let alternates: [ReaderAPIAlternateLocation]
	let categories: [String]
	let origin: ReaderAPIEntryOrigin

	enum CodingKeys: String, CodingKey {
		case articleID = "id"
		case title = "title"
		case summary = "summary"
		case alternates = "alternate"
		case categories = "categories"
		case publishedTimestamp = "published"
		case crawledTimestamp = "crawlTimeMsec"
		case origin = "origin"
		case timestampUsec = "timestampUsec"
	}
	
	func parseDatePublished() -> Date? {
		
		guard let unixTime = publishedTimestamp else {
			return nil
		}
		
		return Date(timeIntervalSince1970: unixTime)
	}
	
	func uniqueID() -> String {
		// Should look something like "tag:google.com,2005:reader/item/00058b10ce338909"
		// REGEX feels heavy, I should be able to just split on / and take the last element
		
		guard let idPart =  articleID.components(separatedBy: "/").last else {
			return articleID
		}
		
		// Convert hex representation back to integer and then a string representation
		guard let idNumber = Int(idPart, radix: 16) else {
			return articleID
		}
		
		return String(idNumber, radix: 10, uppercase: false)
	}
}

struct ReaderAPIArticleSummary: Codable {
	let content: String?
	
	enum CodingKeys: String, CodingKey {
		case content = "content"
	}
}

struct ReaderAPIAlternateLocation: Codable {
	let url: String?
	
	enum CodingKeys: String, CodingKey {
		case url = "href"
	}
}


struct ReaderAPIEntryOrigin: Codable {
	let streamId: String?
	let title: String?

	enum CodingKeys: String, CodingKey {
		case streamId = "streamId"
		case title = "title"
	}
}

