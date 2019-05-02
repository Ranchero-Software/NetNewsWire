//
//  FeedbinAPICaller.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

final class FeedbinAPICaller: NSObject {
	
	private static let feedbinBaseURL = "https://api.feedbin.com/v2/"
	private var session: URLSession!

	override init() {
		
		super.init()
		
		let sessionConfiguration = URLSessionConfiguration.default
		sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
		sessionConfiguration.timeoutIntervalForRequest = 60.0
		sessionConfiguration.httpShouldSetCookies = false
		sessionConfiguration.httpCookieAcceptPolicy = .never
		sessionConfiguration.httpMaximumConnectionsPerHost = 2
		sessionConfiguration.httpCookieStorage = nil
		sessionConfiguration.urlCache = nil
		
		if let userAgentHeaders = UserAgent.headers() {
			sessionConfiguration.httpAdditionalHeaders = userAgentHeaders
		}
		
		session = URLSession(configuration: sessionConfiguration)
		
	}
	
	func validateCredentials(username: String, password: String, completionHandler handler: @escaping APIResultBlock) {
		let request = URLRequest(url: urlFromRelativePath("authentication.json"), username: username, password: password)
		let call = APICall(session: session, request: request)
		call.execute(completionHandler: handler)
	}
	
}

// MARK: Private

private extension FeedbinAPICaller {
	
	func urlFromRelativePath(_ path: String) -> URL {
		let fullPath = "\(FeedbinAPICaller.feedbinBaseURL)\(path)"
		return URL(string: fullPath)!
	}
	
}
