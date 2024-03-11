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

		return Int(long(forColumnIndex: 0))
	}
}

