//
//  OPMLAttributes.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

// OPML allows for arbitrary attributes. These are the common attributes in
// OPML files used as RSS subscription lists. Case-insensitive lookup
// because a frequent error in OPML files is messed-up capitalization.

public extension Dictionary where Key == String, Value == String {

	var opmlText: String? { caseInsensitiveValue(forKey: "text") }
	var opmlTitle: String? { caseInsensitiveValue(forKey: "title") }
	var opmlDescription: String? { caseInsensitiveValue(forKey: "description") }
	var opmlType: String? { caseInsensitiveValue(forKey: "type") }
	var opmlVersion: String? { caseInsensitiveValue(forKey: "version") }
	var opmlHMTLURL: String? { caseInsensitiveValue(forKey: "htmlUrl") }
	var opmlXMLURL: String? { caseInsensitiveValue(forKey: "xmlUrl") }
}

private extension Dictionary where Key == String, Value == String {

	func caseInsensitiveValue(forKey key: String) -> String? {
		if let value = self[key] {
			return value
		}
		for (k, v) in self where k.caseInsensitiveCompare(key) == .orderedSame {
			return v
		}
		return nil
	}
}
