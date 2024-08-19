//
//  OPMLAttributes.swift
//  
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

// OPML allows for arbitrary attributes.
// These are the common attributes in OPML files used as RSS subscription lists.

private static let opmlTextKey = "text"
private static let opmlTitleKey = "title"
private static let opmlDescriptionKey = "description"
private static let opmlTypeKey = "type"
private static let opmlVersionKey = "version"
private static let opmlHMTLURLKey = "htmlUrl"
private static let opmlXMLURLKey = "xmlUrl"

// A frequent error in OPML files is to mess up the capitalization,
// so these do a case-insensitive lookup.

extension Dictionary where Key == String, Value == String {

	var opml_text: String? {
		object(forCaseInsensitiveKey: opmlTextKey)
	}

	var opml_title: String? {
		object(forCaseInsensitiveKey: opmlTitleKey)
	}

	var opml_description: String? {
		object(forCaseInsensitiveKey: opmlDescriptionKey)
	}

	var opml_type: String? {
		object(forCaseInsensitiveKey: opmlTypeKey)
	}

	var opml_version: String? {
		object(forCaseInsensitiveKey: opmlVersionKey)
	}

	var opml_htmlUrl: String? {
		object(forCaseInsensitiveKey: opmlHMTLURLKey)
	}

	var opml_xmlUrl: String? {
		object(forCaseInsensitiveKey: opmlXMLURLKey)
	}
}
