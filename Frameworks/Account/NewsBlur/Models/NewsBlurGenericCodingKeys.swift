//
//  NewsBlurGenericCodingKeys.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-10.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct NewsBlurGenericCodingKeys: CodingKey {
	var stringValue: String

	init?(stringValue: String) {
		self.stringValue = stringValue
	}

	var intValue: Int? {
		return nil
	}

	init?(intValue: Int) {
		return nil
	}
}
