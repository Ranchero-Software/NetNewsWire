//
//  HTMLAttributes.swift
//  RSParser
//
//  Created by Brent Simmons on 4/19/26.
//

// Lightweight view over attributes parsed from an HTML start tag.
//
// HTML attribute names are case-insensitive; values are kept as-is (already
// entity-decoded by the scanner). Lookups are case-insensitive against an
// all-lowercase literal. `dictionary()` returns a String-keyed dict with
// the original-case names — preserves the shape the existing `RSHTMLTag`
// consumer expects.

public struct HTMLAttributes: Sendable {

	let attributes: [(name: ArraySlice<UInt8>, value: String)]

	init(attributes: [(name: ArraySlice<UInt8>, value: String)]) {
		self.attributes = attributes
	}

	public static let empty = HTMLAttributes(attributes: [])

	public var count: Int {
		attributes.count
	}

	public var isEmpty: Bool {
		attributes.isEmpty
	}

	/// Case-insensitive lookup. `name` must be all lowercase.
	public subscript(name: String) -> String? {
		let needle = Array(name.utf8)
		for attribute in attributes {
			if attribute.name.count != needle.count {
				continue
			}
			var match = true
			for (ai, bi) in zip(attribute.name, needle) {
				if ai.asciiLowercased != bi {
					match = false
					break
				}
			}
			if match {
				return attribute.value
			}
		}
		return nil
	}

	/// Materialize a `[String: String]` dictionary with original-case names.
	public func dictionary() -> [String: String] {
		var dict = [String: String]()
		dict.reserveCapacity(attributes.count)
		for attribute in attributes {
			let key = String(decoding: attribute.name, as: UTF8.self)
			dict[key] = attribute.value
		}
		return dict
	}
}
