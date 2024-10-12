//
//  Cache.swift
//
//
//  Created by Brent Simmons on 10/12/24.
//

import Foundation
import os

public protocol CacheRecord: Sendable {
	var dateCreated: Date { get }
}

final class Cache: Sendable {

	public let timeToLive: TimeInterval
	public let timeBetweenCleanups: TimeInterval

	private struct State: Sendable {
		var lastCleanupDate = Date()
		var cache = [String: CacheRecord]()
	}

	private let stateLock = OSAllocatedUnfairLock(initialState: State())

	public init(timeToLive: TimeInterval, timeBetweenCleanups: TimeInterval) {
		self.timeToLive = timeToLive
		self.timeBetweenCleanups = timeBetweenCleanups
	}

	public subscript(_ key: String) -> CacheRecord? {
		get {
			stateLock.withLock { state in

				cleanupIfNeeded(&state)

				guard let value = state.cache[key] else {
					return nil
				}
				if value.dateCreated.timeIntervalSinceNow < -timeToLive {
					state.cache[key] = nil
					return nil
				}
				
				return value
			}
		}
		set {
			stateLock.withLock { state in
				state.cache[key] = newValue
			}
		}
	}
}

extension Cache {

	private func cleanupIfNeeded(_ state: inout State) {

		let currentDate = Date()
		guard state.lastCleanupDate.timeIntervalSince(currentDate) < -timeBetweenCleanups else {
			return
		}

		var keysToDelete = [String]()
		for (key, value) in state.cache {
			if value.dateCreated.timeIntervalSince(currentDate) < -timeToLive {
				keysToDelete.append(key)
			}
		}

		for key in keysToDelete {
			state.cache[key] = nil
		}

		state.lastCleanupDate = Date()
	}
}
