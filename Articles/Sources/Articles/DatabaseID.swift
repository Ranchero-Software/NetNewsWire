//
//  DatabaseID.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/15/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import FoundationExtras
import os

final class DatabaseIDCache: Sendable {

	static let shared = DatabaseIDCache()

	private let _databaseIDCache = OSAllocatedUnfairLock(initialState: [String: String]())
	private var databaseIDCache: [String: String] {
		get {
			_databaseIDCache.withLock { $0 }
		}
		set {
			_databaseIDCache.withLock { $0 = newValue }
		}
	}

	/// Generates — or retrieves from cache — a database-suitable ID based on a String.
	func databaseIDWithString(_ s: String) -> String {

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
