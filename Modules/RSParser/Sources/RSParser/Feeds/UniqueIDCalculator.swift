//
//  UniqueIDCalculator.swift
//  RSParser
//
//  Created by Brent Simmons on 2026-04-24.
//

import Foundation

/// UniqueID calculator for RSS and Atom feed items.
///
struct UniqueIDCalculator {

	/// Concatenate a combination of properties when no guid. Then hash the result.
	/// In general, feeds should have guids. When they don't, re-runs are very likely,
	/// because there's no other 100% reliable way to determine identity.
	/// This is intended to create an ID unique inside a feed, but not globally unique.
	/// Not suitable for a database ID, in other words.
	static func calculate(guid: String?,
	                      permalink: String?,
	                      link: String?,
	                      title: String?,
	                      body: String?,
	                      datePublished: Date?) -> String {
		if let guid, !guid.isEmpty {
			return guid
		}

		let datePublishedString: String?
		if let datePublished {
			datePublishedString = String(format: "%.0f", datePublished.timeIntervalSince1970)
		} else {
			datePublishedString = nil
		}

		var s = ""
		// Ideally we have a permalink and a pubDate. Either one would
		// probably be a good guid, but together they should be rock-solid.
		// (In theory. Feeds are buggy, though.)
		if let permalink, !permalink.isEmpty, let datePublishedString {
			s = permalink + datePublishedString
		} else if let link, !link.isEmpty, let datePublishedString {
			s = link + datePublishedString
		} else if let title, !title.isEmpty, let datePublishedString {
			s = title + datePublishedString
		} else if let datePublishedString {
			s = datePublishedString
		} else if let permalink, !permalink.isEmpty {
			s = permalink
		} else if let link, !link.isEmpty {
			s = link
		} else if let title, !title.isEmpty {
			s = title
		} else if let body, !body.isEmpty {
			s = body
		}
		return s.md5String
	}
}
