//
//  HTTPConditionalGetInfo.swift
//  RSWeb
//
//  Created by Brent Simmons on 4/11/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct HTTPConditionalGetInfo: Codable {
	
	public let lastModified: String?
	public let etag: String?
	public var isEmpty: Bool {
		get {
			return lastModified == nil && etag == nil
		}
	}
	
	public init(lastModified: String?, etag: String?) {
		
		self.lastModified = lastModified
		self.etag = etag
	}
	
	public init(urlResponse: HTTPURLResponse) {
	
		let lastModified = urlResponse.valueForHTTPHeaderField(HTTPResponseHeader.lastModified)
		let etag = urlResponse.valueForHTTPHeaderField(HTTPResponseHeader.etag)
		
		self.init(lastModified: lastModified, etag: etag)
	}
	
	public func addRequestHeadersToURLRequest(_ urlRequest: NSMutableURLRequest) {
		
		if let lastModified = lastModified {
			urlRequest.addValue(lastModified, forHTTPHeaderField: HTTPRequestHeader.ifModifiedSince)
		}
		if let etag = etag {
			urlRequest.addValue(etag, forHTTPHeaderField: HTTPRequestHeader.ifNoneMatch)
		}
	}
}
