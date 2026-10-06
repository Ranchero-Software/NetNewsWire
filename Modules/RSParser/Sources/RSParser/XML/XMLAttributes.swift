//
//  XMLAttributes.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

// Lightweight view over parsed attributes from a start-tag.
//
// Each attribute carries its XMLNamespace (with prefix and resolved URI)
// plus its local name and entity-expanded value as `ArraySlice<UInt8>` views.
// On the fast path (no entity expansion), these slices are views into the
// parser's input buffer with no copying. When expansion changes the bytes,
// the slice wraps a fresh owned `[UInt8]`.

public struct XMLAttributes: Sendable {

	struct Attribute: Sendable {
		let namespace: XMLNamespace
		let localNameSlice: ArraySlice<UInt8>
		let valueSlice: ArraySlice<UInt8>

		var localName: String {
			String(decoding: localNameSlice, as: UTF8.self)
		}

		var value: String {
			String(decoding: valueSlice, as: UTF8.self)
		}

		var qualifiedName: String {
			if let prefix = namespace.prefix {
				return "\(prefix):\(localName)"
			}
			return localName
		}
	}

	let attributes: [Attribute]

	init(attributes: [Attribute]) {
		self.attributes = attributes
	}

	public static let empty = XMLAttributes(attributes: [])

	public var count: Int {
		attributes.count
	}

	public var isEmpty: Bool {
		attributes.isEmpty
	}

	// MARK: - Lookup

	/// Case-sensitive qualified-name lookup. `name` may include a prefix (`xml:lang`)
	/// or be unqualified (`href`).
	public subscript(name: String) -> String? {
		value(forName: name, caseInsensitive: false)
	}

	/// Case-insensitive qualified-name lookup — for RSS authors who mess up attribute
	/// casing (`isPermaLink` vs `ispermalink`).
	public func value(forNameCaseInsensitive name: String) -> String? {
		value(forName: name, caseInsensitive: true)
	}

	/// Materialize a `[String: String]` dictionary of qualified names → values.
	public func dictionary() -> [String: String] {
		var dict = [String: String]()
		dict.reserveCapacity(attributes.count)
		for attribute in attributes {
			dict[attribute.qualifiedName] = attribute.value
		}
		return dict
	}

	/// Iterate over all attributes.
	public func forEach(_ body: (_ namespace: XMLNamespace, _ localName: String, _ value: String) -> Void) {
		for attribute in attributes {
			body(attribute.namespace, attribute.localName, attribute.value)
		}
	}
}

// MARK: - Private

private extension XMLAttributes {

	func value(forName name: String, caseInsensitive: Bool) -> String? {
		let needle = Array(name.utf8)
		for attribute in attributes {
			if matches(attribute: attribute, qualifiedName: needle[...], caseInsensitive: caseInsensitive) {
				return attribute.value
			}
		}
		return nil
	}

	/// Check whether `attribute`'s qualified name (prefix:local or just local) matches `needle`
	/// byte-for-byte. Works directly on the ArraySlice views — no materialized strings.
	func matches(attribute: Attribute, qualifiedName needle: ArraySlice<UInt8>, caseInsensitive: Bool) -> Bool {
		guard let colonIndex = needle.firstIndex(of: .asciiColon) else {
			// No colon: only matches unprefixed attributes.
			guard attribute.namespace.prefix == nil else {
				return false
			}
			return equalBytes(attribute.localNameSlice, needle, caseInsensitive: caseInsensitive)
		}

		// Prefixed needle: require a matching prefix.
		guard let attributePrefix = attribute.namespace.prefix else {
			return false
		}
		let needlePrefix = needle[needle.startIndex..<colonIndex]
		let needleLocal = needle[(colonIndex + 1)...]
		return equalBytes(attributePrefix.utf8, needlePrefix, caseInsensitive: caseInsensitive)
			&& equalBytes(attribute.localNameSlice, needleLocal, caseInsensitive: caseInsensitive)
	}

	/// Generic over two `Collection`s of `UInt8` so we can compare an `ArraySlice<UInt8>`
	/// against a `String.UTF8View` without allocating an intermediate array.
	func equalBytes<A: Collection, B: Collection>(_ a: A, _ b: B, caseInsensitive: Bool) -> Bool
	where A.Element == UInt8, B.Element == UInt8 {
		guard a.count == b.count else {
			return false
		}
		// Hoist the case branch out of the inner loop.
		if caseInsensitive {
			for (ai, bi) in zip(a, b) {
				if ai.asciiLowercased != bi.asciiLowercased {
					return false
				}
			}
		} else {
			for (ai, bi) in zip(a, b) {
				if ai != bi {
					return false
				}
			}
		}
		return true
	}
}
