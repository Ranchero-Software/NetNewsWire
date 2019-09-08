//
//  URLRequest+RSWeb.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

public extension URLRequest {
	
	init(url: URL, credentials: Credentials?, conditionalGet: HTTPConditionalGetInfo? = nil) {
		
		self.init(url: url)
		
		guard let credentials = credentials else {
			return
		}
		
		switch credentials {
		case .basic(let username, let password):
			let data = "\(username):\(password)".data(using: .utf8)
			let base64 = data?.base64EncodedString()
			let auth = "Basic \(base64 ?? "")"
			setValue(auth, forHTTPHeaderField: HTTPRequestHeader.authorization)
        case .readerAPIBasicLogin(let username, let password):
            setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            httpMethod = "POST"
            let postData = "Email=\(username)&Passwd=\(password)"
            httpBody = postData.data(using: String.Encoding.utf8)
        case .readerAPIAuthLogin(_, let apiKey):
            let auth = "GoogleLogin auth=\(apiKey)"
            setValue(auth, forHTTPHeaderField: HTTPRequestHeader.authorization)
        case .oauthAccessToken(_, let token):
            let auth = "OAuth \(token)"
            setValue(auth, forHTTPHeaderField: "Authorization")
        case .oauthRefreshToken:
            // While both access and refresh tokens are credentials, it seems the `Credentials` cases
            // enumerates how the identity of the user can be proved rather than
            // credentials-in-general, such as in this refresh token case,
            // the authority to prove an identity.
            // TODO: Refactor as usage becomes clearer.
            assertionFailure("Refresh tokens are used to replace expired access tokens. Did you mean to use `accessToken` instead?")
            break
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
