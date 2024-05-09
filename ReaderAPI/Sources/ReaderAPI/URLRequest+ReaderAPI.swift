//
//  URLRequest+ReaderAPI.swift
//
//
//  Created by Brent Simmons on 4/6/24.
//

import Foundation
import Secrets
import Web

extension URLRequest {

	init(url: URL, readerAPICredentials: Credentials?, conditionalGet: HTTPConditionalGetInfo? = nil) {

		self.init(url: url)

		guard let credentials = readerAPICredentials else {
			return
		}

		let credentialsType = credentials.type
		precondition(credentialsType == .readerBasic || credentialsType == .readerAPIKey)

		if credentialsType == .readerBasic {

			setValue(MimeType.formURLEncoded, forHTTPHeaderField: "Content-Type")
			httpMethod = "POST"
			var postData = URLComponents()
			postData.queryItems = [
				URLQueryItem(name: "Email", value: credentials.username),
				URLQueryItem(name: "Passwd", value: credentials.secret)
			]
			httpBody = postData.enhancedPercentEncodedQuery?.data(using: .utf8)

		} else if credentialsType == .readerAPIKey {

			let auth = "GoogleLogin auth=\(credentials.secret)"
			setValue(auth, forHTTPHeaderField: HTTPRequestHeader.authorization)
		}

		conditionalGet?.addRequestHeadersToURLRequest(&self)
	}
}
