//
//  Array-Extensions.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 01/04/2021.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation

extension Array {
	
	/// Splits an array in to chunks of size `size`.
	/// - Note: Code from [Hacking with Swift](https://www.hackingwithswift.com/example-code/language/how-to-split-an-array-into-chunks).
	/// - Parameter size: The size of the chunk.
	/// - Returns: An array of `[Element]`s.
	func chunked(into size: Int) -> [[Element]] {
		return stride(from: 0, to: count, by: size).map {
			Array(self[$0 ..< Swift.min($0 + size, count)])
		}
	}
}
