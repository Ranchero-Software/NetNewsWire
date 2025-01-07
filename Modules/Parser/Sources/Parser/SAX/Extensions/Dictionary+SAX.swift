//
//  Dictionary+Parser.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public extension Dictionary where Key == String, Value == String {

	func object(forCaseInsensitiveKey key: String) -> String? {

		if let object = self[key] {
			return object
		}
		
		let lowercaseKey = key.lowercased()

		for (oneKey, oneValue) in self {
			if lowercaseKey.caseInsensitiveCompare(oneKey) == .orderedSame {
				return oneValue
			}
		}

		return nil
	}
}
