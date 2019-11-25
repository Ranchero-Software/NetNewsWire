//
//  FeedWranglerAuthorizationResult.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-11-20.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedWranglerAuthorizationResult: Hashable, Codable {

	let accessToken: String?
	let error: String?
	let result: String

	
	enum CodingKeys: String, CodingKey {
		case accessToken = "access_token"
		case error = "error"
		case result = "result"
	}
}
