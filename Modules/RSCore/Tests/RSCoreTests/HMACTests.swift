//
//  HMACTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 2026-04-24.
//

import Testing
@testable import RSCore

@Suite struct HMACTests {

	@Test("Pinned HMAC-SHA1: key=Jefe, data=\"what do you want for nothing?\"")
	func pinnedVectorJefe() {
		// Cross-verified with Python hashlib and `openssl dgst -sha1 -hmac`.
		let signed = "what do you want for nothing?".hmacUsingSHA1(key: "Jefe")
		#expect(signed == "548329b620689206afea507f732f80f41a4c1a75")
	}

	@Test("Empty key and empty message produce HMAC-SHA1 of empty/empty")
	func emptyKeyEmptyMessage() {
		// HMAC-SHA1("", "") is a well-known value confirmable against any
		// HMAC-SHA1 reference implementation (Python, openssl).
		#expect("".hmacUsingSHA1(key: "") == "fbdb1d1b18aa6c08324b7d64b71fb76370690e1d")
	}

	@Test("Emoji message (non-ASCII UTF-8) produces pinned HMAC-SHA1")
	func nonASCIIEmojiMessage() {
		// 🙂 is U+1F642, 4 UTF-8 bytes. HMAC operates on bytes, so the
		// Swift Character count (1) must not be used — this pins the
		// byte-correct result computed via Python hashlib.
		let signed = "🙂".hmacUsingSHA1(key: "k")
		#expect(signed == "442de3a50b8dc6ba238e6049059c4d069d0f2e38")
	}

	@Test("Output is 40 lowercase hex characters")
	func outputFormat() {
		let signed = "arbitrary input".hmacUsingSHA1(key: "arbitrary key")
		#expect(signed.count == 40)
		#expect(signed.allSatisfy { c in
			("0"..."9").contains(c) || ("a"..."f").contains(c)
		})
	}

	@Test("Different keys produce different signatures for the same message")
	func differentKeysDiffer() {
		let message = "The quick brown fox"
		let a = message.hmacUsingSHA1(key: "key-one")
		let b = message.hmacUsingSHA1(key: "key-two")
		#expect(a != b)
	}

	@Test("Same key and message produce deterministic output")
	func deterministic() {
		let message = "https://example.com/article/42"
		let key = "client-secret"
		let a = message.hmacUsingSHA1(key: key)
		let b = message.hmacUsingSHA1(key: key)
		#expect(a == b)
	}

}
