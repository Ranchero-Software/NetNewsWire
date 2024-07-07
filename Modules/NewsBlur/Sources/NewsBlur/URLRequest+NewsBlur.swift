//
//  File.swift
//  
//
//  Created by Brent Simmons on 4/7/24.
//

import Foundation
import Web
import Secrets

public extension URLRequest {

	@MainActor init(url: URL, newsBlurCredentials: Credentials?, conditionalGet: HTTPConditionalGetInfo? = nil) {

		self.init(url: url)

		guard let credentials = newsBlurCredentials else {
			return
		}

		let credentialsType = credentials.type
		precondition(credentialsType == .newsBlurBasic || credentialsType == .newsBlurSessionID)

		if credentialsType == .newsBlurBasic {

			setValue(MimeType.formURLEncoded, forHTTPHeaderField: HTTPRequestHeader.contentType)
			httpMethod = "POST"

			var postData = URLComponents()
			postData.queryItems = [
				URLQueryItem(name: "username", value: credentials.username),
				URLQueryItem(name: "password", value: credentials.secret),
			]
			httpBody = postData.enhancedPercentEncodedQuery?.data(using: .utf8)

		} else if credentialsType == .newsBlurSessionID {
			
			setValue("\(NewsBlurAPICaller.sessionIDCookieKey)=\(credentials.secret)", forHTTPHeaderField: "Cookie")
			httpShouldHandleCookies = true
		}

		conditionalGet?.addRequestHeadersToURLRequest(&self)
	}
}
