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
	func apiCall(_ call: APICall, handleErrorWith: HTTPResult, returnedObject: Any?)
	func apiCall(_ call: APICall, performActionWith: HTTPResult, returnedObject: Any?)
}

public struct APICall {

	public let provider: WebServiceProvider
	public let methodName: String
	public let identifier: Int
	private let delegate: APICallDelegate
	private static var incrementingIdentifier = 0

	public init(provider: WebServiceProvider, methodName: String, delegate: APICallDelegate) {

		self.provider = provider
		self.methodName = methodName
		self.delegate = delegate

		self.identifier = APICall.incrementingIdentifier
		APICall.incrementingIdentifier += 1
	}
}

