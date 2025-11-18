//
//  DatabaseObjectCache.swift
//  RSDatabase
//
//  Created by Brent Simmons on 9/12/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization

public final class DatabaseObjectCache: Sendable {
	private let state = Mutex([String: DatabaseObject]())

	public init() {
		//
	}
	public func add(_ databaseObjects: [DatabaseObject]) {
		state.withLock { d in
			for databaseObject in databaseObjects {
				d[databaseObject.databaseID] = databaseObject
			}
		}
	}

	public subscript(_ databaseID: String) -> DatabaseObject? {
		get {
			state.withLock { $0[databaseID] }
		}
		set {
			state.withLock { $0[databaseID] = newValue }
		}
	}
}
