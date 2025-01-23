//
//  Set+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 3/13/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension Set {

	func anyObjectPassingTest( _ test: (Element) -> Bool) -> Element? {

		guard let index = self.firstIndex(where: test) else {
			return nil
		}

		return self[index]
	}

	func anyObject() -> Element? {

		if self.isEmpty {
			return nil
		}
		return self[startIndex]
	}
}
