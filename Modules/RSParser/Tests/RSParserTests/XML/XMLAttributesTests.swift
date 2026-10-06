//
//  XMLAttributesTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import Foundation
import Testing
@testable import RSParser

// Direct tests for XMLAttributes lookup, dictionary building, and iteration.
// The scanner exercises this code end-to-end via feed parsing; these tests
// pin down the contract at the unit level where regressions could otherwise hide.

@Suite struct XMLAttributesTests {

	// MARK: - Helpers

	private func makeAttribute(prefix: String? = nil,
	                           localName: String,
	                           value: String,
	                           uri: String? = nil) -> XMLAttributes.Attribute {
		XMLAttributes.Attribute(
			namespace: XMLNamespace(prefix: prefix, uri: uri),
			localNameSlice: ArraySlice(localName.utf8),
			valueSlice: ArraySlice(value.utf8)
		)
	}

	private func make(_ attributes: XMLAttributes.Attribute...) -> XMLAttributes {
		XMLAttributes(attributes: attributes)
	}

	// MARK: - Construction & emptiness

	@Test func emptySingletonIsEmpty() {
		#expect(XMLAttributes.empty.count == 0)
		#expect(XMLAttributes.empty.isEmpty)
	}

	@Test func countAndIsEmpty() {
		let a = make(makeAttribute(localName: "href", value: "/"))
		#expect(a.count == 1)
		#expect(!a.isEmpty)
	}

	// MARK: - Attribute computed vars

	@Test func attributeLocalName() {
		let attr = makeAttribute(localName: "href", value: "/")
		#expect(attr.localName == "href")
	}

	@Test func attributeValue() {
		let attr = makeAttribute(localName: "href", value: "https://example.com")
		#expect(attr.value == "https://example.com")
	}

	@Test func attributeQualifiedNameUnprefixed() {
		let attr = makeAttribute(localName: "href", value: "/")
		#expect(attr.qualifiedName == "href")
	}

	@Test func attributeQualifiedNamePrefixed() {
		let attr = makeAttribute(prefix: "xml", localName: "lang", value: "en",
		                         uri: "http://www.w3.org/XML/1998/namespace")
		#expect(attr.qualifiedName == "xml:lang")
	}

	// MARK: - Case-sensitive lookup (subscript)

	@Test func subscriptFindsUnprefixedAttribute() {
		let a = make(makeAttribute(localName: "href", value: "/foo"))
		#expect(a["href"] == "/foo")
	}

	@Test func subscriptIsCaseSensitive() {
		let a = make(makeAttribute(localName: "href", value: "/foo"))
		#expect(a["HREF"] == nil)
		#expect(a["Href"] == nil)
	}

	@Test func subscriptReturnsNilForMissing() {
		let a = make(makeAttribute(localName: "href", value: "/foo"))
		#expect(a["type"] == nil)
	}

	@Test func subscriptFindsPrefixedAttributeWithQualifiedName() {
		let a = make(makeAttribute(prefix: "xml", localName: "lang", value: "en",
		                           uri: "http://www.w3.org/XML/1998/namespace"))
		#expect(a["xml:lang"] == "en")
	}

	@Test func subscriptPrefixedAttributeDoesNotMatchBareLocalName() {
		// Prefixed attr "xml:lang" should NOT match a bare query "lang".
		let a = make(makeAttribute(prefix: "xml", localName: "lang", value: "en",
		                           uri: "http://www.w3.org/XML/1998/namespace"))
		#expect(a["lang"] == nil)
	}

	@Test func subscriptUnprefixedAttributeDoesNotMatchQualifiedQuery() {
		// Unprefixed attr "lang" should NOT match a qualified query "xml:lang".
		let a = make(makeAttribute(localName: "lang", value: "en"))
		#expect(a["xml:lang"] == nil)
	}

	@Test func subscriptWrongPrefixFails() {
		let a = make(makeAttribute(prefix: "xml", localName: "lang", value: "en",
		                           uri: "http://www.w3.org/XML/1998/namespace"))
		#expect(a["foo:lang"] == nil)
	}

	// MARK: - Case-insensitive lookup

	@Test func caseInsensitiveMatchesMixedCaseLocalName() {
		// RSS's `isPermaLink` vs authors typing `ispermalink`.
		let a = make(makeAttribute(localName: "isPermaLink", value: "false"))
		#expect(a.value(forNameCaseInsensitive: "ispermalink") == "false")
		#expect(a.value(forNameCaseInsensitive: "ISPERMALINK") == "false")
		#expect(a.value(forNameCaseInsensitive: "IsPermaLink") == "false")
	}

	@Test func caseInsensitiveMatchesPrefixAndLocal() {
		let a = make(makeAttribute(prefix: "XML", localName: "Lang", value: "en",
		                           uri: "http://www.w3.org/XML/1998/namespace"))
		#expect(a.value(forNameCaseInsensitive: "xml:lang") == "en")
	}

	@Test func caseInsensitiveDoesNotAffectNonLetters() {
		// Hyphens/digits/punctuation compare byte-for-byte even under case-insensitive.
		let a = make(makeAttribute(localName: "data-id", value: "42"))
		#expect(a.value(forNameCaseInsensitive: "data-id") == "42")
		#expect(a.value(forNameCaseInsensitive: "data_id") == nil)
	}

	// MARK: - dictionary()

	@Test func dictionaryBuildsQualifiedKeys() {
		let a = make(
			makeAttribute(localName: "href", value: "/foo"),
			makeAttribute(prefix: "xml", localName: "lang", value: "en",
			              uri: "http://www.w3.org/XML/1998/namespace")
		)
		let dict = a.dictionary()
		#expect(dict.count == 2)
		#expect(dict["href"] == "/foo")
		#expect(dict["xml:lang"] == "en")
	}

	@Test func dictionaryFromEmptyIsEmpty() {
		#expect(XMLAttributes.empty.dictionary().isEmpty)
	}

	@Test func dictionaryLastWinsOnDuplicateKeys() {
		// Two attributes with identical qualified name — the second wins, matching
		// Swift's standard dict[...] = value assignment semantics.
		let a = make(
			makeAttribute(localName: "x", value: "first"),
			makeAttribute(localName: "x", value: "second")
		)
		#expect(a.dictionary()["x"] == "second")
	}

	// MARK: - forEach

	@Test func forEachVisitsAllAttributesInOrder() {
		let a = make(
			makeAttribute(localName: "a", value: "1"),
			makeAttribute(prefix: "ns", localName: "b", value: "2", uri: "urn:ns"),
			makeAttribute(localName: "c", value: "3")
		)
		var collected: [(prefix: String?, local: String, value: String)] = []
		a.forEach { ns, local, value in
			collected.append((ns.prefix, local, value))
		}
		#expect(collected.count == 3)
		#expect(collected[0].prefix == nil && collected[0].local == "a" && collected[0].value == "1")
		#expect(collected[1].prefix == "ns" && collected[1].local == "b" && collected[1].value == "2")
		#expect(collected[2].prefix == nil && collected[2].local == "c" && collected[2].value == "3")
	}

	@Test func forEachOnEmptyIsNoop() {
		var count = 0
		XMLAttributes.empty.forEach { _, _, _ in count += 1 }
		#expect(count == 0)
	}

	// MARK: - Values with unicode

	@Test func valuesRoundTripUnicode() {
		let a = make(makeAttribute(localName: "title", value: "Café — résumé 日本語"))
		#expect(a["title"] == "Café — résumé 日本語")
	}
}
