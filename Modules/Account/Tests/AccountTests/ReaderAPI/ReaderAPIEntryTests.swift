//
//  ReaderAPIEntryTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 9/1/26.
//

import Foundation
import Testing
@testable import Account

struct ReaderAPIEntryTests {

	@Test func lowIDConvertsToDecimal() throws {
		let entry = try makeEntry(articleID: "tag:google.com,2005:reader/item/00058b10ce338909")
		#expect(entry.uniqueID(variant: .freshRSS) == "1560279178774793")
	}

	@Test func highBitIDDoesNotOverflow() throws {
		// The signed Int(_, radix: 16) returned nil here, so the whole tag string leaked
		// through as the ID and the status was classed unsendable and dropped.
		let entry = try makeEntry(articleID: "tag:google.com,2005:reader/item/ffffffffffffcdef")
		#expect(entry.uniqueID(variant: .freshRSS) == "-12817")
	}

	@Test func zeroID() throws {
		let entry = try makeEntry(articleID: "tag:google.com,2005:reader/item/0000000000000000")
		#expect(entry.uniqueID(variant: .freshRSS) == "0")
	}

	@Test func nonHexIDReturnsArticleIDUnchanged() throws {
		let articleID = "tag:google.com,2005:reader/item/notavalidhexvalue"
		let entry = try makeEntry(articleID: articleID)
		#expect(entry.uniqueID(variant: .freshRSS) == articleID)
	}

	@Test func theOldReaderReturnsRawIDPart() throws {
		let entry = try makeEntry(articleID: "tag:google.com,2005:reader/item/00058b10ce338909")
		#expect(entry.uniqueID(variant: .theOldReader) == "00058b10ce338909")
	}

	@Test func decimalRoundTripsToOriginalHex() throws {
		let hexIDs = ["00058b10ce338909", "ffffffffffffcdef", "0000000000000000"]
		for hex in hexIDs {
			let entry = try makeEntry(articleID: "tag:google.com,2005:reader/item/\(hex)")
			let decimal = entry.uniqueID(variant: .freshRSS)
			// Mirror itemIDParameter's inverse — the decimal must re-encode to the original hex.
			let value = try #require(Int(decimal))
			#expect(String(format: "%.16llx", value) == hex)
		}
	}

	private func makeEntry(articleID: String) throws -> ReaderAPIEntry {
		let json = "{\"id\":\"\(articleID)\",\"summary\":{},\"categories\":[],\"origin\":{}}"
		return try JSONDecoder().decode(ReaderAPIEntry.self, from: Data(json.utf8))
	}
}
