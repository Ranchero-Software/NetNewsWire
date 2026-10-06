//
//  DatabaseTests.swift
//  RSDatabase
//
//  Created by Brent Simmons on 4/24/25.
//

import Testing
import Foundation
import RSDatabase
import RSDatabaseObjC

/// Verifies that `FMResultSet.swiftString(forColumn:)` produces Swift
/// strings with native UTF-8 storage for all inputs, including non-ASCII
/// content that the legacy `string(forColumn:)` path leaves as a lazy
/// `NSString`-backed (UTF-16) bridge.
///
/// `String.isContiguousUTF8` is `true` only for native UTF-8 Swift strings;
/// for bridged `NSString`-backed strings without a fast UTF-8 path it is `false`.
@Suite("FMDB string storage")
struct DatabaseTests {

	@Test func swiftStringPathProducesContiguousUTF8ForAllContent() throws {
		// New path: swiftString(forColumn:) must produce native UTF-8 Swift
		// strings (isContiguousUTF8 == true) for every input, regardless of
		// content — this is the whole point of bypassing NSString.
		let database = try #require(FMDatabase(path: ":memory:"))
		#expect(database.open())
		defer {
			database.close()
		}

		#expect(database.executeUpdate("CREATE TABLE t (id INTEGER PRIMARY KEY, s TEXT)", withArgumentsIn: []))

		for (index, value) in Self.testInputs.enumerated() {
			let didSucceed = database.executeUpdate("INSERT INTO t (id, s) VALUES (?, ?)", withArgumentsIn: [index, value])
			#expect(didSucceed, "Insert failed at row \(index)")
		}

		let resultSet = try #require(database.executeQuery("SELECT id, s FROM t ORDER BY id", withArgumentsIn: []))
		defer {
			resultSet.close()
		}

		var rowsRead = 0
		while resultSet.next() {
			let index = Int(resultSet.int(forColumn: "id"))
			let s = try #require(resultSet.swiftString(forColumn: "s"))
			let original = Self.testInputs[index]
			#expect(s == original, "Round-trip mismatch at row \(index)")
			let label = Self.testInputLabels[index]
			print("[FMDB-swiftString-path] row=\(index) label=\(label) isContiguousUTF8=\(s.isContiguousUTF8) utf8.count=\(s.utf8.count) sample=\(s.prefix(40))")
			#expect(s.isContiguousUTF8, "swiftString(forColumn:) returned non-contiguous storage at row \(index) label=\(label)")
			rowsRead += 1
		}
		#expect(rowsRead == Self.testInputs.count, "Did not read every row")
	}

	@Test func swiftStringHandlesSQLNullAndEmpty() throws {
		let database = try #require(FMDatabase(path: ":memory:"))
		#expect(database.open())
		defer {
			database.close()
		}

		#expect(database.executeUpdate("CREATE TABLE t (id INTEGER PRIMARY KEY, s TEXT)", withArgumentsIn: []))
		#expect(database.executeUpdate("INSERT INTO t (id, s) VALUES (0, NULL)", withArgumentsIn: []))
		#expect(database.executeUpdate("INSERT INTO t (id, s) VALUES (1, '')", withArgumentsIn: []))

		let resultSet = try #require(database.executeQuery("SELECT id, s FROM t ORDER BY id", withArgumentsIn: []))
		defer {
			resultSet.close()
		}

		#expect(resultSet.next())
		#expect(resultSet.swiftString(forColumn: "s") == nil, "SQL NULL must read back as nil")

		#expect(resultSet.next())
		#expect(resultSet.swiftString(forColumn: "s") == "", "Empty TEXT must read back as empty String, not nil")
	}

	// MARK: - Test Fixtures

	private static let testInputLabels: [String] = [
		"ascii",
		"latin-extended",
		"emoji",
		"cjk",
		"long-mixed"
	]

	private static let testInputs: [String] = [
		"Hello World",
		"Café — Über alles",
		"Launch day 🚀🎉",
		"你好世界 こんにちは",
		makeLongMixedBody()
	]

	private static func makeLongMixedBody() -> String {
		let pieces = [
			"The quick brown fox jumps over the lazy dog. ",
			"Café — résumé déjà-vu naïveté façade jalapeño piñata. ",
			"Launch day 🚀🎉🌍 — feedback welcome. ",
			"你好世界 こんにちは 안녕하세요. "
		]
		var body = ""
		while body.utf8.count < 2048 {
			for p in pieces {
				body.append(p)
			}
		}
		return body
	}
}
