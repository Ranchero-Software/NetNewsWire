//
//  String+HTMLEntities.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

// Scans a string for `&…;` entity references and expands them via `XMLEntities.decode`
// using `.html` mode (predefined XML, numeric, and HTML named entities). Unrecognized
// entities pass through literally.

public extension String {

	/// Return the string with all HTML entities (named, decimal, hex) decoded.
	/// Unknown entities pass through as-is.
	func decodingHTMLEntities() -> String {
		// Fast path: scan UTF-8 bytes for `&`. If the string has no
		// ampersand, there are no entities — return it unchanged
		// without building an `Array<UInt8>` of the whole thing.
		//
		// Surprise lesson: `String.UTF8View.contains(_:)` on a
		// 100 KB body benched ~75x *slower* than
		// `Array(utf8).contains(_:)` — the UTF8View iterates
		// through a generic sequence, while `Array<UInt8>.contains`
		// compiles to a vectorized byte scan over contiguous
		// memory. Going through `withContiguousStorageIfAvailable`
		// on the UTF8 view gets us the same `UnsafeBufferPointer
		// <UInt8>.contains` fast path without ever allocating an
		// `Array`. For the (rare) non-contiguous case — a bridged
		// `NSString` backed by UTF-16 — we fall back to the generic
		// iterator.
		let hasAmpersand: Bool = utf8.withContiguousStorageIfAvailable { buffer in
			buffer.contains(UInt8(ascii: "&"))
		} ?? utf8.contains(UInt8(ascii: "&"))

		if !hasAmpersand {
			return self
		}
		// Slow path: an ampersand appeared, so an entity *might* be
		// present. Materialize the bytes once for random access by
		// `XMLEntities.decode`, then rebuild the decoded string.
		let bytes = Array(utf8)
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
