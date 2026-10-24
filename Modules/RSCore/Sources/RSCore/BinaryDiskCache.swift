//
//  BinaryDiskCache.swift
//  RSCore
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization

nonisolated public final class BinaryDiskCache: Sendable {
	public let folder: String
	private let mutex = Mutex(())

	public init(folder: String) {
		self.folder = folder
	}

	public func data(forKey key: String) throws -> Data? {
		try mutex.withLock { _ in
			try _data(forKey: key)
		}
	}

	public func setData(_ data: Data, forKey key: String) throws {
		try mutex.withLock { _ in
			try _setData(data, forKey: key)
		}
	}

	public func deleteData(forKey key: String) throws {
		try mutex.withLock { _ in
			try _deleteData(forKey: key)
		}
	}

	// Subscript doesn’t throw. Use when you can ignore errors.

	public subscript(_ key: String) -> Data? {
		get {
			mutex.withLock { _ in
				do {
					return try _data(forKey: key)
				} catch {}
				return nil
			}
		}

		set {
			mutex.withLock { _ in
				if let data = newValue {
					do {
						try _setData(data, forKey: key)
					} catch {}
				} else {
					do {
						try _deleteData(forKey: key)
					} catch {}
				}
			}
		}
	}
}

nonisolated private extension BinaryDiskCache {

	func _data(forKey key: String) throws -> Data? {
		let url = urlForKey(key)
		return try Data(contentsOf: url)
	}

	func _setData(_ data: Data, forKey key: String) throws {
		let url = urlForKey(key)
		try data.write(to: url)
	}

	func _deleteData(forKey key: String) throws {
		let url = urlForKey(key)
		try FileManager.default.removeItem(at: url)
	}

	func filePath(forKey key: String) -> String {
		(folder as NSString).appendingPathComponent(key)
	}

	func urlForKey(_ key: String) -> URL {
		let f = filePath(forKey: key)
		return URL(fileURLWithPath: f)
	}
}
