//
//  OPMLAttributes.swift
//  
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

// OPML allows for arbitrary attributes.
// These are the common attributes in OPML files used as RSS subscription lists.

private let opmlTextKey = "text"
private let opmlTitleKey = "title"
private let opmlDescriptionKey = "description"
private let opmlTypeKey = "type"
private let opmlVersionKey = "version"
private let opmlHMTLURLKey = "htmlUrl"
private let opmlXMLURLKey = "xmlUrl"

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
