//
//  BinaryDiskCache.swift
//  RSCore
//
//  Created by Brent Simmons on 11/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Thread safety is up to the caller.

public struct BinaryDiskCache {

	public let folder: String

	public init(folder: String) {

		self.folder = folder
	}

	public func data(forKey key: String) throws -> Data? {

		let url = urlForKey(key)
		do {
			let data = try Data(contentsOf: url)
			return data
		}
		catch {
			throw error
		}
	}

	public func setData(_ data: Data, forKey key: String) throws {

		let url = urlForKey(key)
		do {
			try data.write(to: url)
		}
		catch {
			throw error
		}
	}

	public func deleteData(forKey key: String) throws {

		let url = urlForKey(key)
		do {
			try FileManager.default.removeItem(at: url)
		}
		catch {
			throw error
		}
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
