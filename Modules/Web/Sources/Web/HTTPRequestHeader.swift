//
//  HTTPRequestHeader.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct HTTPRequestHeader {

	public static let userAgent = "User-Agent"
	public static let authorization = "Authorization"
	public static let contentType = "Content-Type"
	public static let acceptType = "Accept-Type"
	
	// Conditional GET
	
	public static let ifModifiedSince = "If-Modified-Since"
	public static let ifNoneMatch = "If-None-Match" //Etag
}
