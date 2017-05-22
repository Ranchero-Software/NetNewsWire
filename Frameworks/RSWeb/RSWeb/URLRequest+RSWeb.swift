//
//  URLRequest+RSWeb.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/27/16.
//  Copyright © 2016 Ranchero Software. All rights reserved.
//

import Foundation

public extension URLRequest {
	
	// Experimental. Returns nil if scheme isn't http or https (about:blank, for instance).
	
	public func loadingURL() -> URL? {
		
		guard let url = mainDocumentURL else {
			return nil
		}
		guard url.isHTTPOrHTTPSURL() else {
			return nil
		}
		guard !url.absoluteString.isEmpty else {
			return nil
		}
		
		return url
	}
}
