//
//  NSMutableDictionary-Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 8/20/16.
//  Copyright © 2016 Ranchero Software. All rights reserved.
//

import Foundation

public extension NSMutableDictionary {

	public func setOptionalStringValue(_ stringValue: String?, _ key: String) {

		if let s = stringValue {
			setObjectWithStringKey(s as NSString, key)
		}
	}

	public func setObjectWithStringKey(_ obj: Any, _ key: String) {

		setObject(obj, forKey: key as NSString)
	}
}
