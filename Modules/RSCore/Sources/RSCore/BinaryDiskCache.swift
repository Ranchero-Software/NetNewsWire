//
//  BinaryDiskCache.swift
//  RSCore
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// Each key is its own file. Writes are atomic.
nonisolated public final class BinaryDiskCache: Sendable {
	public let folder: String

	public init(folder: String) {
		self.folder = folder
	}

	public func data(forKey key: String) throws -> Data? {
		try _data(forKey: key)
	}

	public func setData(_ data: Data, forKey key: String) throws {
		try _setData(data, forKey: key)
	}

	public func deleteData(forKey key: String) throws {
		try _deleteData(forKey: key)
	}

	// Subscript doesn’t throw. Use when you can ignore errors.

	public subscript(_ key: String) -> Data? {
		get {
			do {
				return try _data(forKey: key)
			} catch {}
			return nil
		}

		set {
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

nonisolated private extension BinaryDiskCache {

	func _data(forKey key: String) throws -> Data? {
		let url = urlForKey(key)
		// Mapped, so the bytes are file-backed pages the system can reclaim, not heap memory.
		return try Data(contentsOf: url, options: .mappedIfSafe)
	}

	func _setData(_ data: Data, forKey key: String) throws {
		let url = urlForKey(key)
		try data.write(to: url, options: .atomic)
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
