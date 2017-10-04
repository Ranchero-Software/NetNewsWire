//
//  NSURL+RSWeb.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

private struct URLConstants {
	static let schemeHTTP = "http"
	static let schemeHTTPS = "https"
	static let prefixHTTP = "http://"
	static let prefixHTTPS = "https://"
}

public extension URL {
	
	public func isHTTPSURL() -> Bool {
		
		return self.scheme?.lowercased() == URLConstants.schemeHTTPS
	}
	
	public func isHTTPURL() -> Bool {
		
		return self.scheme?.lowercased() == URLConstants.schemeHTTP
	}
	
	public func isHTTPOrHTTPSURL() -> Bool {
		
		return self.isHTTPSURL() || self.isHTTPURL()
	}
	
	public func absoluteStringWithHTTPOrHTTPSPrefixRemoved() -> String? {
		
		// Case-inensitive. Turns http://example.com/foo into example.com/foo
		
		if isHTTPSURL() {
			return absoluteString.stringByRemovingCaseInsensitivePrefix(URLConstants.prefixHTTPS)
		}
		else if isHTTPURL() {
			return absoluteString.stringByRemovingCaseInsensitivePrefix(URLConstants.prefixHTTP)
		}
		
		return nil
	}
}

private extension String {

	func stringByRemovingCaseInsensitivePrefix(_ prefix: String) -> String {
		
		// Returns self if it doesn’t have the given prefix.
		
		let lowerPrefix = prefix.lowercased()
		let lowerSelf = self.lowercased()
		
		if (lowerSelf == lowerPrefix) {
			return ""
		}
		if !lowerSelf.hasPrefix(lowerPrefix) {
			return self
		}
		
		let index = self.index(self.startIndex, offsetBy: prefix.count)
		return String(self[..<index])
	}
}
