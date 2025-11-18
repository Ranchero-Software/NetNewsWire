//
//  NewsBlurLoginResponse.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-09.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct NewsBlurLoginResponse: Decodable, Sendable {
	let code: Int
	let errors: LoginError?

	struct LoginError: Decodable, Sendable {
		let username: [String]?
		let others: [String]?
	}
}

extension NewsBlurLoginResponse.LoginError {
	private enum CodingKeys: String, CodingKey {
		case username = "username"
		case others = "__all__"
	}
}
