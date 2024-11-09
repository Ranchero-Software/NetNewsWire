//
//  ODBTests.swift
//  RSDatabaseTests
//
//  Created by Brent Simmons on 8/27/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSDatabase

class ODBTests: XCTestCase {

	func testODBCreation() {
		let odb = genericTestODB()
		closeAndDelete(odb)
	}

	func testSimpleBoolStorage() {
		let odb = genericTestODB()
		let path = ODBPath.path(["testBool"])
		path.setRawValue(true, odb: odb)

		XCTAssertEqual(path.rawValue(with: odb) as! Bool, true)
		closeAndDelete(odb)
	}

	func testSimpleIntStorage() {
		let odb = genericTestODB()
		let path = ODBPath.path(["TestInt"])
		let intValue = 3487456
		path.setRawValue(intValue, odb: odb)

		XCTAssertEqual(path.rawValue(with: odb) as! Int, intValue)
		closeAndDelete(odb)
	}

	func testSimpleDoubleStorage() {
		let odb = genericTestODB()
		let path = ODBPath.path(["TestDouble"])
		let doubleValue = 3498.45745
		path.setRawValue(doubleValue, odb: odb)

		XCTAssertEqual(path.rawValue(with: odb) as! Double, doubleValue)
		closeAndDelete(odb)
	}

	func testReadSimpleBoolPerformance() {
		let odb = genericTestODB()
		let path = ODBPath.path(["TestBool"])
		path.setRawValue(true, odb: odb)
		XCTAssertEqual(path.rawValue(with: odb) as! Bool, true)

		self.measure {
			let _ = path.rawValue(with: odb)
		}
		closeAndDelete(odb)
	}

	func testSetSimpleUnchangingBoolPerformance() {
		let odb = genericTestODB()
		let path = ODBPath.path(["TestBool"])
		self.measure {
			path.setRawValue(true, odb: odb)
		}
		closeAndDelete(odb)
	}

	func testReadAndCloseAndReadSimpleBool() {
		let f = pathForTestFile("testReadAndCloseAndReadSimpleBool.odb")
		var odb = ODB(filepath: f)
		let path = ODBPath.path(["testBool"])
		path.setRawValue(true, odb: odb)

		XCTAssertEqual(path.rawValue(with: odb) as! Bool, true)
		odb.close()

		odb = ODB(filepath: f)
		XCTAssertEqual(path.rawValue(with: odb) as! Bool, true)
		closeAndDelete(odb)
	}

	func testReplaceSimpleObject() {
		let odb = genericTestODB()
		let path = ODBPath.path(["TestValue"])
		let intValue = 3487456
		path.setRawValue(intValue, odb: odb)

		XCTAssertEqual(path.rawValue(with: odb) as! Int, intValue)

		let stringValue = "test string value"
		path.setRawValue(stringValue, odb: odb)
		XCTAssertEqual(path.rawValue(with: odb) as! String, stringValue)

		closeAndDelete(odb)
	}

	func testEnsureTable() {
		let odb = genericTestODB()
		let path = ODBPath.path(["A", "B", "C", "D"])
		let _ = path.ensureTable(with: odb)
		closeAndDelete(odb)
	}

	func testEnsureTablePerformance() {
		let odb = genericTestODB()
		let path = ODBPath.path(["A", "B", "C", "D"])

		self.measure {
			let _ = path.ensureTable(with: odb)
		}

		closeAndDelete(odb)
	}

	func testStoreDateInSubtable() {
		let odb = genericTestODB()
		let path = ODBPath.path(["A", "B", "C", "D"])
		path.ensureTable(with: odb)
		
		let d = Date()
		let datePath = path + "TestValue"
		datePath.setRawValue(d, odb: odb)
		XCTAssertEqual(datePath.rawValue(with: odb) as! Date, d)
		closeAndDelete(odb)
	}
}

private extension ODBTests {

	func tempFolderPath() -> String {
		return FileManager.default.temporaryDirectory.path
	}

	func pathForTestFile(_ name: String) -> String {
		let folder = tempFolderPath()
		return (folder as NSString).appendingPathComponent(name)
	}

	static var databaseFileID = 0;

	func pathForGenericTestFile() -> String {
		ODBTests.databaseFileID += 1
		return pathForTestFile("Test\(ODBTests.databaseFileID).odb")
	}

	func genericTestODB() -> ODB {
		let f = pathForGenericTestFile()
		return ODB(filepath: f)
	}

	func closeAndDelete(_ odb: ODB) {
		odb.close()
		try! FileManager.default.removeItem(atPath: odb.filepath)
	}
}
