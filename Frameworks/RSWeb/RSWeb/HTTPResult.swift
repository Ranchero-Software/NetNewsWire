//
//  HTTPResult.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/10/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

public struct HTTPResult {

	public let url: URL
	public let data: Data?
	public let response: URLResponse?
	public let error: Error?

	public init(url: URL, data: Data?, response: URLResponse?, error: Error?) {
		
		self.url = url
		self.data = data
		self.response = response
		self.error = error
	}
}
