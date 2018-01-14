//
//  String+RSWeb.swift
//  RSWeb
//
//  Created by Brent Simmons on 1/13/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Foundation

public extension String {

	public func encodedForURLQuery() -> String? {

		guard let encodedString = addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
			return nil
		}
		return encodedString.replacingOccurrences(of: "&", with: "%38")
	}
}
