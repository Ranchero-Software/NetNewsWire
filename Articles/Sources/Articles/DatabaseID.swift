//
//  DatabaseID.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/15/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

class DatabaseIDCache: @unchecked Sendable {

	static let shared = DatabaseIDCache()

	private var databaseIDCache = [String: String]()
	private let databaseIDCacheLock = NSLock()

	/// Generates — or retrieves from cache — a database-suitable ID based on a String.
	func databaseIDWithString(_ s: String) -> String {

		databaseIDCacheLock.lock()
		defer {
			databaseIDCacheLock.unlock()
		}

		if let identifier = databaseIDCache[s] {
			return identifier
		}

		// MD5 works because:
		// * It’s fast
		// * Collisions aren’t going to happen with feed data
		let identifier = s.md5String
		databaseIDCache[s] = identifier
		return identifier
	}
}
