//
//  Dictionary+RSWeb.swift
//  RSWeb
//
//  Created by Brent Simmons on 1/13/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Foundation

public extension Dictionary  {

	public func urlQueryString() -> String? {

		// Turn a dictionary into string like foo=bar&param2=some%20thing
		// Return nil if empty dictionary.

		if isEmpty {
			return nil
		}

		var s = ""
		var numberAdded = 0
		for (key, value) in self {

			guard let key = key as? String, let value = value as? String else {
				continue
			}
			guard let encodedKey = key.encodedForURLQuery(), let encodedValue = value.encodedForURLQuery() else {
				continue
			}

			if numberAdded > 0 {
				s += "&"
			}
			s += "\(encodedKey)=\(encodedValue)"
			numberAdded += 1
		}

		if numberAdded < 1 {
			return nil
		}
		
		return s
	}
}
