//
//  APICall.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/9/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

// Main thread only.

public protocol APICallDelegate {

	func apiCallURLRequest(_ call: APICall) -> URLRequest?
	func apiCall(_ call: APICall, parseReturnedObjectWith: HTTPResult) -> Any?
	func apiCall(_ call: APICall, handleErrorWith: HTTPResult)
	func apiCall(_ call: APICall, performActionWith: HTTPResult)
}

public final class APICall {

	// Create request. Call server. Create result. Create returned object. Run action.

	public let provider: WebServiceProvider
	public let url: URL
	public let credentials: Credentials?
	public let methodName: String
	public let identifier: Int
	private let delegate: APICallDelegate
	private static var incrementingIdentifier = 0

	init(provider: WebServiceProvider, url: URL, credentials: Credentials?, methodName: String, delegate: APICallDelegate) {

		self.provider = provider
		self.url = url
		self.credentials = credentials
		self.methodName = methodName

		self.identifier = APICall.incrementingIdentifier
		APICall.incrementingIdentifier += 1
	}
}

