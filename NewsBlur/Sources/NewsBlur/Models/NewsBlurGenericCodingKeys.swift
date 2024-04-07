//
//  NewsBlurGenericCodingKeys.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-10.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct NewsBlurGenericCodingKeys: CodingKey {

	public var stringValue: String

	public init?(stringValue: String) {
		self.stringValue = stringValue
	}

	public var intValue: Int? {
		return nil
	}

	public init?(intValue: Int) {
		return nil
	}
}
