//
//  PropertyList.swift
//  RSCore
//
//  Created by Brent Simmons on 7/12/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// These functions eat errors.

public func propertyList(withData data: Data) -> Any? {

	do {
		return try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
	} catch {
		return nil
	}
}

// Create a binary plist.

public func data(withPropertyList plist: Any) -> Data? {

	do {
		return try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
	}
	catch {
		return nil
	}
}
