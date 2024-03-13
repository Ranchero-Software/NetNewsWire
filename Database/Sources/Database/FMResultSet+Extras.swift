//
//  File.swift
//  
//
//  Created by Brent Simmons on 3/10/24.
//

import Foundation
import FMDB

public extension FMResultSet {

	func intWithCountResult() -> Int? {

		guard next() else {
			return nil
		}

		let count = Int(long(forColumnIndex: 0))
		close()
		
		return count
	}

	func compactMap<T>(_ completion: (_ row: FMResultSet) -> T?) -> [T] {

		var objects = [T]()
		while next() {
			if let obj = completion(self) {
				objects += [obj]
			}
		}
		close()
		return objects
	}

	func mapToSet<T>(_ completion: (_ row: FMResultSet) -> T?) -> Set<T> {

		return Set(compactMap(completion))
	}
}

