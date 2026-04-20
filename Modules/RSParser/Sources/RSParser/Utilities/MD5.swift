//
//  MD5.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation
import CryptoKit

private let hexDigits: [UInt8] = Array("0123456789abcdef".utf8)

extension String {

	/// MD5 hash of the string's UTF-8 bytes, formatted as 32 lowercase hex characters.
	var md5String: String {
		let digest = Insecure.MD5.hash(data: Data(utf8))
		// Build the 32-byte hex buffer directly from the 16 digest bytes — no per-byte
		// String allocations, no printf format-string parsing.
		var hex = [UInt8](repeating: 0, count: 32)
		var i = 0
		for byte in digest {
			hex[i]     = hexDigits[Int(byte >> 4)]
			hex[i + 1] = hexDigits[Int(byte & 0x0F)]
			i += 2
		}
		return String(decoding: hex, as: UTF8.self)
	}
}
