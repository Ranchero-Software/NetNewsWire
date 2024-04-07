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

			setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
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

		guard let conditionalGet = conditionalGet else {
			return
		}

		// Bug seen in the wild: lastModified with last possible 32-bit date, which is in 2038. Ignore those.
		// TODO: drop this check in late 2037.
		if let lastModified = conditionalGet.lastModified, !lastModified.contains("2038") {
			setValue(lastModified, forHTTPHeaderField: HTTPRequestHeader.ifModifiedSince)
		}
		if let etag = conditionalGet.etag {
			setValue(etag, forHTTPHeaderField: HTTPRequestHeader.ifNoneMatch)
		}
	}
}
