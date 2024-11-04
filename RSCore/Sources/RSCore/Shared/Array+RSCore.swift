//
//  Array+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension Array {

	func chunked(into size: Int) -> [[Element]] {
		return stride(from: 0, to: count, by: size).map {
			Array(self[$0 ..< Swift.min($0 + size, count)])
		}
	}
	
}

public extension Array where Element: Equatable {

	mutating func removeFirst(object: Element) {
		guard let index = firstIndex(of: object) else {return}
		remove(at: index)
	}

}
