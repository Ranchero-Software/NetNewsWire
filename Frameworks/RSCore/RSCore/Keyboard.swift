//
//  Keyboard.swift
//  RSCore
//
//  Created by Brent Simmons on 12/19/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// To get, for instance, the keyboard integer value for "\r": "\r".keyboardIntegerValue (returns 13)

public struct KeyboardConstant {

	public static let lineFeedKey = "\n".keyboardIntegerValue
	public static let returnKey = "\r".keyboardIntegerValue
}

public extension String {

	public var keyboardIntegerValue: Int {
		return Int(utf8[utf8.startIndex])
	}
}
