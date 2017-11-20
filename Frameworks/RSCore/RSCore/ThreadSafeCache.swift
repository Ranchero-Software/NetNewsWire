//
//  ThreadSafeCache.swift
//  RSCore
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class ThreadSafeCache<T> {

	private var cache = [String: T]()
	private let lock = NSLock()

	public init() {}
	
	public subscript(_ key: String) -> T? {
		get {
			return cachedObject(key)
		}
		set {
			if let newValue = newValue {
				cacheObject(key, newValue)
			}
		}
	}

	private func cachedObject(_ key: String) -> T? {

		lock.lock()
		defer {
			lock.unlock()
		}

		return cache[key]
	}

	private func cacheObject(_ key: String, _ value: T) {

		lock.lock()
		defer {
			lock.unlock()
		}

		cache[key] = value
	}
}
