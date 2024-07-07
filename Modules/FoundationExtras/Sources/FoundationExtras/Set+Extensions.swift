//
//  Set+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 3/13/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension Set {

	func anyObject() -> Element? {
		
		if self.isEmpty {
			return nil
		}
		return self[startIndex]
	}
}
