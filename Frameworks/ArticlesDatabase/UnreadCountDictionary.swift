//
//  UnreadCountDictionary.swift
//  Database
//
//  Created by Brent Simmons on 8/31/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles

public struct UnreadCountDictionary {

	private var dictionary = [String: Int]()

	public var isEmpty: Bool {
		return dictionary.count < 1
	}

	public subscript(_ feedID: String) -> Int? {
		get {
			return dictionary[feedID]
		}
		set {
			dictionary[feedID] = newValue
		}
	}
}
