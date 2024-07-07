//
//  BinaryDiskCache.swift
//  RSCore
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public actor BinaryDiskCache {

	public let folder: String

	public init(folder: String) {
		self.folder = folder
	}

	public func data(forKey key: String) throws -> Data? {
		let url = urlForKey(key)
		return try Data(contentsOf: url)
	}

	public func setData(_ data: Data, forKey key: String) throws {
		let url = urlForKey(key)
		try data.write(to: url)
	}

	public func deleteData(forKey key: String) throws {
		let url = urlForKey(key)
		try FileManager.default.removeItem(at: url)
	}

	// subscript doesn’t throw, for cases when you can ignore errors.

	public subscript(_ key: String) -> Data? {
		get {
			do {
				return try data(forKey: key)
			}
			catch {}
			return nil
		}
		
		set {
			if let data = newValue {
				do {
					try setData(data, forKey: key)
				}
				catch {}
			}
			else {
				do {
					try deleteData(forKey: key)
				}
				catch{}
			}
		}
	}
}

private extension BinaryDiskCache {

	func filePath(forKey key: String) -> String {
		return (folder as NSString).appendingPathComponent(key)
	}

	func urlForKey(_ key: String) -> URL {
		let f = filePath(forKey: key)
		return URL(fileURLWithPath: f)
	}
}
