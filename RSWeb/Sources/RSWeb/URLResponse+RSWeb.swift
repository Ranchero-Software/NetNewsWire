//
//  URLResponse+RSWeb.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/14/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension URLResponse {
	
	var statusIsOK: Bool {
		return forcedStatusCode >= 200 && forcedStatusCode <= 299
	}
	
	var forcedStatusCode: Int {
		
		// Return actual statusCode or 0 if there isn’t one.
		
		if let response = self as? HTTPURLResponse {
			return response.statusCode
		}
		return 0
	}
}

public extension HTTPURLResponse {
	
	func valueForHTTPHeaderField(_ headerField: String) -> String? {
		
		// Case-insensitive. HTTP headers may not be in the case you expect.
		
		let lowerHeaderField = headerField.lowercased()
		
		for (key, value) in allHeaderFields {
			
			if lowerHeaderField == (key as? String)?.lowercased() {
				return value as? String
			}
		}
		
		return nil
	}
}
