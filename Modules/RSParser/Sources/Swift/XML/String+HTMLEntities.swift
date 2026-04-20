//
//  String+HTMLEntities.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

// Swift replacement for the old ObjC `-[NSString rsparser_stringByDecodingHTMLEntities]`.
// Scans a string for `&…;` entity references and expands them via `XMLEntities.decode`
// using `.html` mode (predefined XML, numeric, and HTML named entities). Unrecognized
// entities pass through literally — matches libxml2 HTML-parser behavior.

public extension String {

	/// Return the string with all HTML entities (named, decimal, hex) decoded.
	/// Unknown entities pass through as-is.
	func decodingHTMLEntities() -> String {
		let bytes = Array(utf8)
		// Fast path: if no `&`, the string has no entities — return it unchanged.
		if !bytes.contains(UInt8(ascii: "&")) {
			return self
		}
		var out = [UInt8]()
		out.reserveCapacity(bytes.count)
		var i = 0
		while i < bytes.count {
			let b = bytes[i]
			if b == UInt8(ascii: "&") {
				let decoded = XMLEntities.decode(bytes: bytes, at: i, mode: .html)
				out.append(contentsOf: decoded.bytes)
				i = decoded.nextIndex
			} else {
				out.append(b)
				i += 1
			}
		}
		return String(decoding: out, as: UTF8.self)
	}
}
