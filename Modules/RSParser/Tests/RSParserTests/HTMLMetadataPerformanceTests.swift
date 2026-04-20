//
//  HTMLMetadataPerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import XCTest
import RSParser
import RSParserObjC

// Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }` equivalent yet.

final class HTMLMetadataPerformanceTests: XCTestCase {

	func testDaringFireballPerformance() {
		// 0.002 sec on my 2012 iMac
		let d = parserData("DaringFireball", "html", "http://daringfireball.net/")
		self.measure {
			_ = RSHTMLMetadataParser.htmlMetadata(with: d)
		}
	}

	func testFurboPerformance() {
		// 0.001 sec on my 2012 iMac
		let d = parserData("furbo", "html", "http://furbo.org/")
		self.measure {
			_ = RSHTMLMetadataParser.htmlMetadata(with: d)
		}
	}

	func testInessentialPerformance() {
		// 0.001 sec on my 2012 iMac
		let d = parserData("inessential", "html", "http://inessential.com/")
		self.measure {
			_ = RSHTMLMetadataParser.htmlMetadata(with: d)
		}
	}

	func testCocoPerformance() {
		// 0.004 sec on my 2012 iMac
		let d = parserData("coco", "html", "https://www.theatlantic.com/entertainment/archive/2017/11/coco-is-among-pixars-best-movies-in-years/546695/")
		self.measure {
			_ = RSHTMLMetadataParser.htmlMetadata(with: d)
		}
	}

	func testSixColorsPerformance() {
		// 0.002 sec on my 2012 iMac
		let d = parserData("sixcolors", "html", "http://sixcolors.com/")
		self.measure {
			_ = RSHTMLMetadataParser.htmlMetadata(with: d)
		}
	}
}
