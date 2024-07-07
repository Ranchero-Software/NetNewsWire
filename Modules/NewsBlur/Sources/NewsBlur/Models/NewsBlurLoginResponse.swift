//
//  NewsBlurLoginResponse.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-09.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct NewsBlurLoginResponse: Decodable, Sendable {

	public var code: Int
	public var errors: LoginError?

	public struct LoginError: Decodable, Sendable {

		public var username: [String]?
		public var others: [String]?
	}
}

extension NewsBlurLoginResponse.LoginError {
	
	private enum CodingKeys: String, CodingKey {
		case username = "username"
		case others = "__all__"
	}
}
