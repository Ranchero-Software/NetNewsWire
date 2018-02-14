//
//  HTTPConditionalGetInfo.swift
//  RSWeb
//
//  Created by Brent Simmons on 4/11/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct HTTPConditionalGetInfo {
	
	public let lastModified: String?
	public let etag: String?
	
	public var dictionary: [String: String] {
		var d = [String: String]()
		if let lastModified = lastModified {
			d[HTTPResponseHeader.lastModified] = lastModified
		}
		if let etag = etag {
			d[HTTPResponseHeader.etag] = etag
		}
		return d
	}
	
	public init?(lastModified: String?, etag: String?) {

		if lastModified == nil && etag == nil {
			return nil
		}
		self.lastModified = lastModified
		self.etag = etag
	}
	
	public init?(urlResponse: HTTPURLResponse) {
	
		let lastModified = urlResponse.valueForHTTPHeaderField(HTTPResponseHeader.lastModified)
		let etag = urlResponse.valueForHTTPHeaderField(HTTPResponseHeader.etag)
		
		self.init(lastModified: lastModified, etag: etag)
	}

	public init?(dictionary: [String: String]) {

		self.init(lastModified: dictionary[HTTPResponseHeader.lastModified], etag: dictionary[HTTPResponseHeader.etag])
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
