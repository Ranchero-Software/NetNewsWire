//
//  RSSArticle.swift
//
//
//  Created by Brent Simmons on 8/27/24.
//

import Foundation
//import FoundationExtras

final class RSSArticle {

	var feedURL: String

	/// An RSS guid, if present, or calculated from other attributes.
	/// Should be unique to the feed, but not necessarily unique
	/// across different feeds. (Not suitable for a database ID.)
	lazy var articleID: String = {
		if let guid {
			return guid
		}
		return calculatedArticleID()
	}()

	var guid: String?
	var title: String?
	var body: String?
	var link: String?
	var permalink: String?
	var authors: [RSSAuthor]?
	var enclosures: [RSSEnclosure]?
	var datePublished: Date?
	var dateModified: Date?
	var dateParsed: Date
	var language: String?

	init(_ feedURL: String) {
		self.feedURL = feedURL
		self.dateParsed = Date()
	}

	func addEnclosure(_ enclosure: RSSEnclosure) {

		if enclosures == nil {
			enclosures = [RSSEnclosure]()
		}
		enclosures!.append(enclosure)
	}

	func addAuthor(_ author: RSSAuthor) {

		if authors == nil {
			authors = [RSSAuthor]()
		}
		authors!.append(author)
	}
}

private extension RSSArticle {

	func calculatedArticleID() -> String {

		// Concatenate a combination of properties when no guid. Then hash the result.
		// In general, feeds should have guids. When they don't, re-runs are very likely,
		// because there's no other 100% reliable way to determine identity.
		// This is intended to create an ID unique inside a feed, but not globally unique.
		// Not suitable for a database ID, in other words.

		var s = ""

		let datePublishedTimeStampString: String? = {
			guard let datePublished else {
				return nil
			}
			return String(format: "%.0f", datePublished.timeIntervalSince1970)
		}()

		// Ideally we have a permalink and a pubDate.
		// Either one would probably be a good guid, but together they should be rock-solid.
		// (In theory. Feeds are buggy, though.)
		if let permalink, !permalink.isEmpty, let datePublishedTimeStampString {
			s.append(permalink)
			s.append(datePublishedTimeStampString)
		}
		else if let link, !link.isEmpty, let datePublishedTimeStampString {
			s.append(link)
			s.append(datePublishedTimeStampString)
		}
		else if let title, !title.isEmpty, let datePublishedTimeStampString {
			s.append(title)
			s.append(datePublishedTimeStampString)
		}
		else if let datePublishedTimeStampString {
			s.append(datePublishedTimeStampString)
		}
		else if let permalink, !permalink.isEmpty {
			s.append(permalink)
		}
		else if let link, !link.isEmpty {
			s.append(link)
		}
		else if let title, !title.isEmpty {
			s.append(title)
		}
		else if let body, !body.isEmpty {
			s.append(body)
		}

		return s.md5String
	}
}
