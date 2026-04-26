//
//  FMResultSet+Extras.swift
//  
//
//  Created by Brent Simmons on 3/10/24.
//

import Foundation
import RSDatabaseObjC

public extension FMResultSet {

	func intWithCountResult() -> Int? {
		guard next() else {
			return nil
		}

		let count = Int(long(forColumnIndex: 0))
		close()

		return count
	}

	func compactMap<T>(_ completion: (_ row: FMResultSet) -> T?) -> [T] {
		var objects = [T]()
		while next() {
			if let obj = completion(self) {
				objects += [obj]
			}
		}
		close()
		return objects
	}

	func mapToSet<T>(_ completion: (_ row: FMResultSet) -> T?) -> Set<T> {
		return Set(compactMap(completion))
	}

	/// Returns a native UTF-8 Swift `String` for a TEXT column, bypassing
	/// `NSString` bridging. Avoids the UTF-16 storage cost typical of
	/// `NSString` for non-ASCII content. Returns `nil` for SQL `NULL`.
	///
	/// Reads through `dataNoCopy(forColumn:)`, which wraps SQLite-owned
	/// bytes; the bytes are consumed synchronously by `String(decoding:as:)`
	/// before this call returns, so the SQLite "valid until next column
	/// access" lifetime is respected.
	func swiftString(forColumn columnName: String) -> String? {
		guard let data = dataNoCopy(forColumn: columnName) else {
			return nil
		}
		return String(decoding: data, as: UTF8.self)
	}

	func swiftString(forColumnIndex columnIdx: Int32) -> String? {
		guard let data = dataNoCopy(forColumnIndex: columnIdx) else {
			return nil
		}
		return String(decoding: data, as: UTF8.self)
	}
}
