//
//  HTTPResponseHeader.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct HTTPResponseHeader {

	public static let contentType = "Content-Type"
	public static let location = "Location"
	public static let link = "Links"
	public static let date = "Date"

	// Conditional GET. See:
	// http://fishbowl.pastiche.org/2002/10/21/http_conditional_get_for_rss_hackers/
	
	public static let lastModified = "Last-Modified"
	// Changed to the canonical case for lookups against a case sensitive dictionary
	// https://developer.apple.com/documentation/foundation/httpurlresponse/1417930-allheaderfields
	public static let etag = "Etag"
}
