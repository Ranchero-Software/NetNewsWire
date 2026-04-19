//
//  EntityDecodingBenchmark.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import XCTest
@testable import RSParser
import RSParserObjC

// One-shot comparison benchmark: old ObjC `rsparser_stringByDecodingHTMLEntities`
// vs a Swift wrapper around `XMLEntities.decode`. Prints absolute times and the
// speedup ratio. Not meant to be run as part of every test suite.

final class EntityDecodingBenchmark: XCTestCase {

	/// A realistic mix: plain text, predefined XML entities, named HTML entities,
	/// numeric decimal, numeric hex, a worst-case ampersand-heavy input, and an
	/// entity-free input (exercises the no-op path).
	private let inputs: [String] = [
		"Tom &amp; Jerry &mdash; &ldquo;Episode 5&rdquo; (&#8482; 2025)",
		"Caf&eacute;, r&eacute;sum&eacute;, na&iuml;ve. &copy; 2025 &ndash; all rights reserved.",
		"No entities here, just plain text content that's a typical paragraph from a feed article — should exercise the no-work path efficiently.",
		"&#8220;Hello, &quot;world&quot; &#38; everything else&#8221; &#x2014; said the fox.",
		String(repeating: "&amp;", count: 200),
		"<p>Mixed <b>markup</b> &amp; entities: &lt;script&gt; &#x1F600; &#x2764; &mdash; works?</p>",
		"&invalidEntity; &amp; &#999999999; &xyz &; &amp &amp;;"
	]

	private let iterations = 5_000

	func testCompareImplementations() {
		// Warm up: run both implementations a few times so the first iteration doesn't
		// pay for cold caches / lazy dict init (the ObjC path builds its entity dict
		// on first call via dispatch_once).
		for _ in 0..<100 {
			for s in inputs {
				_ = (s as NSString).rsparser_stringByDecodingHTMLEntities()
				_ = Self.swiftDecode(s)
			}
		}

		// Correctness sanity — outputs should be identical for our inputs.
		for s in inputs {
			let objc = (s as NSString).rsparser_stringByDecodingHTMLEntities()
			let swift = Self.swiftDecode(s)
			XCTAssertEqual(objc, swift, "divergence for input \(s.debugDescription)")
		}

		let objcTime = time(label: "ObjC  ") {
			for _ in 0..<iterations {
				for s in inputs {
					_ = (s as NSString).rsparser_stringByDecodingHTMLEntities()
				}
			}
		}

		let swiftTime = time(label: "Swift ") {
			for _ in 0..<iterations {
				for s in inputs {
					_ = Self.swiftDecode(s)
				}
			}
		}

		let speedup = objcTime / swiftTime
		print(String(format: "Speedup: %.2fx (lower Swift time is better)", speedup))
	}

	// MARK: - Helpers

	@discardableResult
	private func time(label: String, _ block: () -> Void) -> Double {
		let start = DispatchTime.now()
		block()
		let end = DispatchTime.now()
		let ms = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
		let perCall = (ms * 1000) / Double(iterations * inputs.count)
		print(String(format: "%@: %7.2f ms total, %5.2f µs/call", label, ms, perCall))
		return ms
	}

	/// Swift equivalent of `rsparser_stringByDecodingHTMLEntities`:
	/// scan a string, expanding every `&…;` entity via `XMLEntities.decode`.
	private static func swiftDecode(_ s: String) -> String {
		let bytes = Array(s.utf8)
		var out: [UInt8] = []
		out.reserveCapacity(bytes.count)
		var i = 0
		while i < bytes.count {
			let b = bytes[i]
			if b == .asciiAmpersand {
				let d = XMLEntities.decode(bytes: bytes, at: i, mode: .normal)
				out.append(contentsOf: d.bytes)
				i = d.nextIndex
			} else {
				out.append(b)
				i += 1
			}
		}
		return String(decoding: out, as: UTF8.self)
	}
}
