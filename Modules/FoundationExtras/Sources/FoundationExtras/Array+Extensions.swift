//
//  Array+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CoreGraphics

public extension Array {

	func chunked(into size: Int) -> [[Element]] {
		return stride(from: 0, to: count, by: size).map {
			Array(self[$0 ..< Swift.min($0 + size, count)])
		}
	}
}

public extension Array where Element == CGRect {

	func maxY() -> CGFloat {

		var y: CGFloat = 0.0
		for r in self {
			y = Swift.max(y, r.maxY)
		}
		return y
	}
}
