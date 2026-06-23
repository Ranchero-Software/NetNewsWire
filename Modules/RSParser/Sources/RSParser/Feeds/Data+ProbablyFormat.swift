//
//  Data+ProbablyFormat.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

import Foundation

// Heuristic byte-level format detection for feed data. Direct port of the
// ObjC `NSData (RSParser)` category. Called once per fetched feed (not hot),
// so clarity over cleverness. For HTML detection use RSCore's public
// `Data.isProbablyHTML`; the properties here cover feed-specific formats.

extension Data {

	/// True if the data begins with `<?xml` (past BOM + whitespace).
	var isProbablyXML: Bool {
		startsWithASCII("<?xml")
	}

	/// True if the data begins with `{` (past BOM + whitespace).
	var isProbablyJSON: Bool {
		startsWithASCII("{")
	}

	/// Probably a JSON Feed per https://jsonfeed.org: JSON that mentions the
	/// `jsonfeed.org/version/` marker, in either canonical or backslash-escaped
	/// form (serializers sometimes escape the slashes).
	var isProbablyJSONFeed: Bool {
		guard isProbablyJSON else {
			return false
		}
		return containsASCII("://jsonfeed.org/version/")
			|| containsASCII(":\\/\\/jsonfeed.org\\/version\\/")
	}

	/// Probably the "RSS in JSON" format: JSON with rss/channel/item markers.
	var isProbablyRSSInJSON: Bool {
		guard isProbablyJSON else {
			return false
		}
		return containsASCII("rss")
			&& containsASCII("channel")
			&& containsASCII("item")
	}

	/// Probably RSS 2.0 or 1.0 (RDF). The `<channel>`/`<pubDate>` fallback
	/// catches feeds like natashatherobot.com that omit the opening `<rss>`.
	var isProbablyRSS: Bool {
		if containsASCII("<rss") || containsASCII("<rdf:RDF") {
			return true
		}
		return containsASCII("<channel>") && containsASCII("<pubDate>")
	}

	/// Probably an Atom feed — mentions `<feed` anywhere.
	var isProbablyAtom: Bool {
		containsASCII("<feed")
	}
}

// MARK: - Private byte scanning

private extension Data {

	/// True if the data contains `needle` as a contiguous ASCII byte sequence.
	func containsASCII(_ needle: String) -> Bool {
		let needleBytes = Array(needle.utf8)
		guard !needleBytes.isEmpty else {
			return true
		}
		return withUnsafeBytes { buffer -> Bool in
			guard let base = buffer.baseAddress else {
				return false
			}
			let ptr = base.assumingMemoryBound(to: UInt8.self)
			let count = buffer.count
			guard count >= needleBytes.count else {
				return false
			}
			let last = count - needleBytes.count
			var i = 0
			while i <= last {
				var matched = true
				for j in 0..<needleBytes.count {
					if ptr[i + j] != needleBytes[j] {
						matched = false
						break
					}
				}
				if matched {
					return true
				}
				i += 1
			}
			return false
		}
	}

	/// True if the first non-whitespace / non-BOM bytes begin with `needle`.
	/// Allows up to 4 leading BOM bytes (UTF-8/UTF-16/UTF-32 BOMs all fit),
	/// then skips ASCII whitespace (`space`, `\r`, `\n`, `\t`).
	func startsWithASCII(_ needle: String) -> Bool {
		let needleBytes = Array(needle.utf8)
		guard !needleBytes.isEmpty else {
			return true
		}
		return withUnsafeBytes { buffer -> Bool in
			guard let base = buffer.baseAddress else {
				return false
			}
			let ptr = base.assumingMemoryBound(to: UInt8.self)
			let count = buffer.count
			var i = 0
			while i < count {
				let byte = ptr[i]
				if byte == UInt8(ascii: " ")
					|| byte == UInt8(ascii: "\r")
					|| byte == UInt8(ascii: "\n")
					|| byte == UInt8(ascii: "\t") {
					i += 1
					continue
				}
				if byte == needleBytes[0] {
					guard count - i >= needleBytes.count else {
						return false
					}
					for j in 0..<needleBytes.count {
						if ptr[i + j] != needleBytes[j] {
							return false
						}
					}
					return true
				}
				// Allow a BOM of up to four bytes at the very start.
				if i < 4 {
					i += 1
					continue
				}
				return false
			}
			return false
		}
	}
}
