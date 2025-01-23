//
//  NSMutableURLRequest+RSWeb.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension URLRequest {

	@discardableResult mutating func addBasicAuthorization(username: String, password: String) -> Bool {

		// Do this *only* with https. And not even then if you can help it.

		let s = "\(username):\(password)"
		guard let d = s.data(using: .utf8, allowLossyConversion: false) else {
			return false
		}

		let base64EncodedString = d.base64EncodedString()
		let authorization = "Basic \(base64EncodedString)"
		setValue(authorization, forHTTPHeaderField: HTTPRequestHeader.authorization)

		return true
	}
}
