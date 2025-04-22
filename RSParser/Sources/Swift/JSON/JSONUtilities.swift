//
//  JSONUtilities.swift
//  RSParser
//
//  Created by Brent Simmons on 12/10/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct JSONUtilities {

	public static func object(with data: Data) -> Any? {

		return try? JSONSerialization.jsonObject(with: data)
	}

	public static func dictionary(with data: Data) -> JSONDictionary? {

		return object(with: data) as? JSONDictionary
	}

	public static func array(with data: Data) -> JSONArray? {

		return object(with: data) as? JSONArray
	}
}
