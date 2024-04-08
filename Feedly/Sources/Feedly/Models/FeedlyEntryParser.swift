//
//  FeedlyEntryParser.swift
//  Account
//
//  Created by Kiel Gillard on 3/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import Parser

public struct FeedlyEntryParser: Sendable {

	public let entry: FeedlyEntry

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()
	
	public var id: String {
		return entry.id
	}
	
	/// When ingesting articles, the feedURL must match a feed's `feedID` for the article to be reachable between it and its matching feed. It reminds me of a foreign key.
	public var feedUrl: String? {
		guard let id = entry.origin?.streamID else {
			// At this point, check Feedly's API isn't glitching or the response has not changed structure.
			assertionFailure("Entries need to be traceable to a feed or this entry will be dropped.")
			return nil
		}
		return id
	}
	
	/// Convoluted external URL logic "documented" here:
	/// https://groups.google.com/forum/#!searchin/feedly-cloud/feed$20url%7Csort:date/feedly-cloud/Rx3dVd4aTFQ/Hf1ZfLJoCQAJ
	public var externalUrl: String? {
		let multidimensionalArrayOfLinks = [entry.canonical, entry.alternate]
		let withExistingValues = multidimensionalArrayOfLinks.compactMap { $0 }
		let flattened = withExistingValues.flatMap { $0 }
		let webPageLinks = flattened.filter { $0.type == nil || $0.type == "text/html" }
		return webPageLinks.first?.href
	}
	
	public var title: String? {
		return rightToLeftTextSantizer.sanitize(entry.title)
	}
	
	public var contentHMTL: String? {
		return entry.content?.content ?? entry.summary?.content
	}
	
	public var contentText: String? {
		// We could strip HTML from contentHTML?
		return nil
	}
	
	public var summary: String? {
		return rightToLeftTextSantizer.sanitize(entry.summary?.content)
	}
	
	public var datePublished: Date {
		return entry.crawled
	}
	
	public var dateModified: Date? {
		return entry.recrawled
	}
	
	public var authors: Set<ParsedAuthor>? {
		guard let name = entry.author else {
			return nil
		}
		return Set([ParsedAuthor(name: name, url: nil, avatarURL: nil, emailAddress: nil)])
	}
	
	/// While there is not yet a tagging interface, articles can still be searched for by tags.
	public var tags: Set<String>? {
		guard let labels = entry.tags?.compactMap({ $0.label }), !labels.isEmpty else {
			return nil
		}
		return Set(labels)
	}
	
	public var attachments: Set<ParsedAttachment>? {
		guard let enclosure = entry.enclosure, !enclosure.isEmpty else {
			return nil
		}
		let attachments = enclosure.compactMap { ParsedAttachment(url: $0.href, mimeType: $0.type, title: nil, sizeInBytes: nil, durationInSeconds: nil) }
		return attachments.isEmpty ? nil : Set(attachments)
	}
	
	public var parsedItemRepresentation: ParsedItem? {
		guard let feedUrl = feedUrl else {
			return nil
		}
		
		return ParsedItem(syncServiceID: id,
						  uniqueID: id, // This value seems to get ignored or replaced.
						  feedURL: feedUrl,
						  url: nil,
						  externalURL: externalUrl,
						  title: title,
						  language: nil,
						  contentHTML: contentHMTL,
						  contentText: contentText,
						  summary: summary,
						  imageURL: nil,
						  bannerImageURL: nil,
						  datePublished: datePublished,
						  dateModified: dateModified,
						  authors: authors,
						  tags: tags,
						  attachments: attachments)
	}
}
