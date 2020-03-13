//
//  NewsBlurDate.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-13.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct NewsBlurDate {
	static let yyyyMMddHHmmss: DateFormatter = {
		let formatter = DateFormatter()
		formatter.calendar = Calendar(identifier: .iso8601)
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(abbreviation: "GMT")
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		return formatter
	}()
}
