//
//  Data+RSCoreTests.swift
//  RSCoreTests
//
//  Created by Nate Weaver on 2020-01-12.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import Foundation
@testable import RSCore

// class Data_RSCoreTests: XCTestCase {
//	var bigHTML: String!
//
//	var pngData: Data!
//	var jpegData: Data!
//	var gifData: Data!
//
//	lazy var bundle = Bundle(for: type(of: self))
//
//	override func setUp() {
//		let htmlFile = bundle.url(forResource: "test", withExtension: "html")!
//		bigHTML = try? String(contentsOf: htmlFile)
//
//		let pngURL = bundle.url(forResource: "icon", withExtension: "png")!
//		pngData = try! Data(contentsOf: pngURL)
//
//		let jpegURL = bundle.url(forResource: "icon", withExtension: "jpg")!
//		jpegData = try! Data(contentsOf: jpegURL)
//
//		let gifURL = bundle.url(forResource: "icon", withExtension: "gif")!
//		gifData = try! Data(contentsOf: gifURL)
//	}
//
//	func testIsProbablyHTMLEncodings() {
//
//		let utf8 = bigHTML.data(using: .utf8)!
//		XCTAssertTrue(utf8.isProbablyHTML)
//
//		let utf16 = bigHTML.data(using: .utf16)!
//		XCTAssertTrue(utf16.isProbablyHTML)
//
//		let utf16Little = bigHTML.data(using: .utf16LittleEndian)!
//		XCTAssertTrue(utf16Little.isProbablyHTML)
//
//		let utf16Big = bigHTML.data(using: .utf16BigEndian)!
//		XCTAssertTrue(utf16Big.isProbablyHTML)
//
//		let shiftJIS = bigHTML.data(using: .shiftJIS)!
//		XCTAssertTrue(shiftJIS.isProbablyHTML)
//
//		let japaneseEUC = bigHTML.data(using: .japaneseEUC)!
//		XCTAssertTrue(japaneseEUC.isProbablyHTML)
//
//	}
//
//	func testIsProbablyHTMLTags() {
//
//		let noLT = "html body".data(using: .utf8)!
//		XCTAssertFalse(noLT.isProbablyHTML)
//
//		let noBody = "<html><head></head></html>".data(using: .utf8)!
//		XCTAssertFalse(noBody.isProbablyHTML)
//
//		let noHead = "<body>foo</body>".data(using: .utf8)!
//		XCTAssertFalse(noHead.isProbablyHTML)
//
//		let lowerHTMLLowerBODY = "<html><body></body></html>".data(using: .utf8)!
//		XCTAssertTrue(lowerHTMLLowerBODY.isProbablyHTML)
//
//		let upperHTMLUpperBODY = "<HTML><BODY></BODY></HTML>".data(using: .utf8)!
//		XCTAssertTrue(upperHTMLUpperBODY.isProbablyHTML)
//
//		let lowerHTMLUpperBODY = "<html><BODY></BODY></html>".data(using: .utf8)!
//		XCTAssertTrue(lowerHTMLUpperBODY.isProbablyHTML)
//
//		let upperHTMLLowerBODY = "<HTML><body></body></HTML>".data(using: .utf8)!
//		XCTAssertTrue(upperHTMLLowerBODY.isProbablyHTML)
//
//	}
//
//	func testIsProbablyHTMLPerformance() {
//		let utf8 = bigHTML.data(using: .utf8)!
//
//		self.measure {
//			for _ in 0 ..< 10000 {
//				let _ = utf8.isProbablyHTML
//			}
//		}
//	}
//
//	func testIsImage() {
//		XCTAssertTrue(pngData.isPNG)
//		XCTAssertTrue(jpegData.isJPEG)
//		XCTAssertTrue(gifData.isGIF)
//
//		XCTAssertTrue(pngData.isImage)
//		XCTAssertTrue(jpegData.isImage)
//		XCTAssertTrue(gifData.isImage)
//	}
//
//	// Shouldn't crash.
//	func testDataIsTooSmall() {
//		let data = Data(count: 2)
//		XCTAssertFalse(data.isJPEG)
//	}
//
//	func testMD5() {
//		let foobarData = "foobar".data(using: .utf8)!
//		XCTAssertEqual(foobarData.md5String, "3858f62230ac3c915f300c664312c63f")
//		
//		let emptyData = Data()
//		XCTAssertEqual(emptyData.md5String, "d41d8cd98f00b204e9800998ecf8427e")
//	}
//
//	func testHexadecimalString() {
//
//		let data = Data([1, 2, 3, 4])
//		XCTAssertEqual(data.hexadecimalString!, "01020304")
//
//		var deadbeef = UInt32(bigEndian: 0xDEADBEEF)
//		let data2 = Data(bytes: &deadbeef, count: MemoryLayout.size(ofValue: deadbeef))
//		XCTAssertEqual(data2.hexadecimalString!, "deadbeef")
//
//	}
//
// }

// Tests to compare the result of Data+RSCore with the old Objective-C versions.
// extension Data_RSCoreTests {
//
//	func testCompare_isProbablyHTML() {
//		let noLT = "html body".data(using: .utf8)!
//		XCTAssertEqual(noLT.isProbablyHTML, (noLT as NSData).rs_dataIsProbablyHTML())
//
//		let noBody = "<html><head></head></html>".data(using: .utf8)!
//		XCTAssertEqual(noBody.isProbablyHTML, (noBody as NSData).rs_dataIsProbablyHTML())
//
//		let noHead = "<body>foo</body>".data(using: .utf8)!
//		XCTAssertEqual(noHead.isProbablyHTML, (noHead as NSData).rs_dataIsProbablyHTML())
//
//		let lowerHTMLLowerBODY = "<html><body></body></html>".data(using: .utf8)!
//		XCTAssertEqual(lowerHTMLLowerBODY.isProbablyHTML, (lowerHTMLLowerBODY as NSData).rs_dataIsProbablyHTML())
//
//		let upperHTMLUpperBODY = "<HTML><BODY></BODY></HTML>".data(using: .utf8)!
//		XCTAssertEqual(upperHTMLUpperBODY.isProbablyHTML, (upperHTMLUpperBODY as NSData).rs_dataIsProbablyHTML())
//
//		let lowerHTMLUpperBODY = "<html><BODY></BODY></html>".data(using: .utf8)!
//		XCTAssertEqual(lowerHTMLUpperBODY.isProbablyHTML, (lowerHTMLUpperBODY as NSData).rs_dataIsProbablyHTML())
//
//		let upperHTMLLowerBODY = "<HTML><body></body></HTML>".data(using: .utf8)!
//		XCTAssertEqual(upperHTMLLowerBODY.isProbablyHTML, (upperHTMLLowerBODY as NSData).rs_dataIsProbablyHTML())
//
//	}
//
//	func testCompare_isImage() {
//		XCTAssertEqual(pngData.isPNG, (pngData as NSData).rs_dataIsPNG())
//		XCTAssertEqual(jpegData.isJPEG, (jpegData as NSData).rs_dataIsJPEG())
//		XCTAssertEqual(gifData.isGIF, (gifData as NSData).rs_dataIsGIF())
//
//		XCTAssertEqual(pngData.isImage, (pngData as NSData).rs_dataIsImage())
//		XCTAssertEqual(jpegData.isImage, (jpegData as NSData).rs_dataIsImage())
//		XCTAssertEqual(gifData.isImage, (gifData as NSData).rs_dataIsImage())
//	}
//
//	func testCompare_MD5() {
//		let foobarData = "foobar".data(using: .utf8)!
//		let emptyData = Data()
//
//		XCTAssertEqual(foobarData.md5Hash, (foobarData as NSData).rs_md5Hash())
//		XCTAssertEqual(emptyData.md5Hash, (emptyData as NSData).rs_md5Hash())
//
//		XCTAssertEqual(foobarData.md5String, (foobarData as NSData).rs_md5HashString())
//		XCTAssertEqual(emptyData.md5String, (emptyData as NSData).rs_md5HashString())
//	}
//
//	func testCompare_hexadecimalString() {
//
//		let data = Data([1, 2, 3, 4])
//		XCTAssertEqual(data.hexadecimalString!, (data as NSData).rs_hexadecimalString())
//
//		var deadbeef = UInt32(bigEndian: 0xDEADBEEF)
//		let data2 = Data(bytes: &deadbeef, count: MemoryLayout.size(ofValue: deadbeef))
//		XCTAssertEqual(data2.hexadecimalString!, (data2 as NSData).rs_hexadecimalString())
//
//	}
//
// }
