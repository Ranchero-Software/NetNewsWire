//
//  DatabaseID.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/15/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Synchronization

private let databaseIDCache = Mutex([String: String]())

public func databaseIDWithString(_ s: String) -> String {
	databaseIDCache.withLock { cache in
		if let identifier = cache[s] {
			return identifier
		}

		// MD5 works because:
		// * It’s fast
		// * Collisions aren’t going to happen with feed data
		let identifier = s.md5String
		cache[s] = identifier
		return identifier
	}
}
