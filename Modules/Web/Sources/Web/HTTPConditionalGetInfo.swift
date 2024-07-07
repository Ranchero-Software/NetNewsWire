//
//  HTTPConditionalGetInfo.swift
//  RSWeb
//
//  Created by Brent Simmons on 4/11/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct HTTPConditionalGetInfo: Codable, Equatable, Sendable {
	
	public let lastModified: String?
	public let etag: String?
	
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

	public init?(headers: [AnyHashable : Any]) {
		let lastModified = headers[HTTPResponseHeader.lastModified] as? String
		let etag = headers[HTTPResponseHeader.etag] as? String
		self.init(lastModified: lastModified, etag: etag)
	}
	
	public func addRequestHeadersToURLRequest(_ urlRequest: inout URLRequest) {
		// Bug seen in the wild: lastModified with last possible 32-bit date, which is in 2038. Ignore those.
		// TODO: drop this check in late 2037.
		if let lastModified = lastModified, !lastModified.contains("2038") {
			urlRequest.setValue(lastModified, forHTTPHeaderField: HTTPRequestHeader.ifModifiedSince)
		}
		if let etag = etag {
			urlRequest.setValue(etag, forHTTPHeaderField: HTTPRequestHeader.ifNoneMatch)
		}
	}
}
