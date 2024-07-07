//
//  FeedbinDate.swift
//  Account
//
//  Created by Maurice Parker on 5/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedbinDate {
	
	public static let formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
		formatter.locale = Locale(identifier: "en_US")
		formatter.timeZone = TimeZone(abbreviation: "GMT")
		return formatter
	}()
}
