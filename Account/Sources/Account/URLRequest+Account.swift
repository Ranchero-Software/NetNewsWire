//
//  URLRequest+Account.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
import Secrets
import NewsBlur

public extension URLRequest {

	@MainActor init(url: URL, credentials: Credentials?, conditionalGet: HTTPConditionalGetInfo? = nil) {

		self.init(url: url)

		guard let credentials = credentials else {
			return
		}

		switch credentials.type {
		case .basic:
			let data = "\(credentials.username):\(credentials.secret)".data(using: .utf8)
			let base64 = data?.base64EncodedString()
			let auth = "Basic \(base64 ?? "")"
			setValue(auth, forHTTPHeaderField: HTTPRequestHeader.authorization)
		case .newsBlurBasic:
			setValue(MimeType.formURLEncoded, forHTTPHeaderField: HTTPRequestHeader.contentType)
			httpMethod = "POST"
			var postData = URLComponents()
			postData.queryItems = [
				URLQueryItem(name: "username", value: credentials.username),
				URLQueryItem(name: "password", value: credentials.secret),
			]
			httpBody = postData.enhancedPercentEncodedQuery?.data(using: .utf8)
		case .newsBlurSessionID:
			setValue("\(NewsBlurAPICaller.sessionIDCookieKey)=\(credentials.secret)", forHTTPHeaderField: "Cookie")
			httpShouldHandleCookies = true
		case .readerBasic:
			setValue(MimeType.formURLEncoded, forHTTPHeaderField: "Content-Type")
			httpMethod = "POST"
			var postData = URLComponents()
			postData.queryItems = [
				URLQueryItem(name: "Email", value: credentials.username),
				URLQueryItem(name: "Passwd", value: credentials.secret)
			]
			httpBody = postData.enhancedPercentEncodedQuery?.data(using: .utf8)
		case .readerAPIKey:
			let auth = "GoogleLogin auth=\(credentials.secret)"
			setValue(auth, forHTTPHeaderField: HTTPRequestHeader.authorization)
		case .oauthAccessToken:
			let auth = "OAuth \(credentials.secret)"
			setValue(auth, forHTTPHeaderField: "Authorization")
		case .oauthAccessTokenSecret:
			assertionFailure("Token secrets are used by OAuth1. Did you mean to use `OAuthSwift` instead of a URLRequest?")
			break
		case .oauthRefreshToken:
			// While both access and refresh tokens are credentials, it seems the `Credentials` cases
			// enumerates how the identity of the user can be proved rather than
			// credentials-in-general, such as in this refresh token case,
			// the authority to prove an identity.
			assertionFailure("Refresh tokens are used to replace expired access tokens. Did you mean to use `accessToken` instead?")
			break
		}

		conditionalGet?.addRequestHeadersToURLRequest(&self)
	}
}
