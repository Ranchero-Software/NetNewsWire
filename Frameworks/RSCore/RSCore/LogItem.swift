//
//  LogItem.swift
//  RSCore
//
//  Created by Brent Simmons on 11/14/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct LogItem {

	public enum ItemType {
		case debug, notification, warning, error
	}

	public let type: ItemType
	public let message: String
	public let date: Date

	public init(type: ItemType, message: String) {

		self.type = type
		self.message = message
		self.date = Date()
	}
}
