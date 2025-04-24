//
//  NewsBlurLoginResponse.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-09.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct NewsBlurLoginResponse: Decodable {
	var code: Int
	var errors: LoginError?

	struct LoginError: Decodable {
		var username: [String]?
		var others: [String]?
	}
}

extension NewsBlurLoginResponse.LoginError {
	private enum CodingKeys: String, CodingKey {
		case username = "username"
		case others = "__all__"
	}
}
