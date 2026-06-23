//
//  XMLNamespaceContextTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import Foundation
import Testing
@testable import RSParser

// Direct tests for XMLNamespaceContext's scope stack. The SAX parser exercises
// this indirectly; these tests pin down the push/pop/resolve contract at the
// unit level where shadowing and pop-order bugs could otherwise hide.

@Suite struct XMLNamespaceContextTests {

	// MARK: - Built-in namespaces

	@Test func xmlPrefixAlwaysResolvesToSpecURI() {
		let ctx = XMLNamespaceContext()
		#expect(ctx.resolve(prefix: "xml") == "http://www.w3.org/XML/1998/namespace")
	}

	@Test func xmlnsPrefixAlwaysResolvesToSpecURI() {
		let ctx = XMLNamespaceContext()
		#expect(ctx.resolve(prefix: "xmlns") == "http://www.w3.org/2000/xmlns/")
	}

	@Test func builtInsArePresentEvenAtDepth() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [(prefix: "dc", uri: "http://purl.org/dc/elements/1.1/")])
		ctx.pushScope(bindings: [(prefix: nil, uri: "http://www.w3.org/2005/Atom")])
		#expect(ctx.resolve(prefix: "xml") == "http://www.w3.org/XML/1998/namespace")
		#expect(ctx.resolve(prefix: "xmlns") == "http://www.w3.org/2000/xmlns/")
	}

	@Test func builtInsCannotBeShadowedByBindings() {
		// Even if a feed tries to rebind `xml`, the built-in wins.
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [(prefix: "xml", uri: "http://evil.example.com/")])
		#expect(ctx.resolve(prefix: "xml") == "http://www.w3.org/XML/1998/namespace")
	}

	// MARK: - Default namespace (nil prefix)

	@Test func defaultNamespaceResolvesWhenBound() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [(prefix: nil, uri: "http://www.w3.org/2005/Atom")])
		#expect(ctx.resolve(prefix: nil) == "http://www.w3.org/2005/Atom")
	}

	@Test func defaultNamespaceReturnsNilWhenUnbound() {
		let ctx = XMLNamespaceContext()
		#expect(ctx.resolve(prefix: nil) == nil)
	}

	// MARK: - Prefix bindings

	@Test func prefixResolvesAfterPush() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [(prefix: "dc", uri: "http://purl.org/dc/elements/1.1/")])
		#expect(ctx.resolve(prefix: "dc") == "http://purl.org/dc/elements/1.1/")
	}

	@Test func unboundPrefixReturnsNil() {
		let ctx = XMLNamespaceContext()
		#expect(ctx.resolve(prefix: "nosuchprefix") == nil)
	}

	@Test func innerScopeShadowsOuter() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [(prefix: "x", uri: "urn:outer")])
		#expect(ctx.resolve(prefix: "x") == "urn:outer")
		ctx.pushScope(bindings: [(prefix: "x", uri: "urn:inner")])
		#expect(ctx.resolve(prefix: "x") == "urn:inner")
	}

	@Test func outerBindingVisibleFromInnerScopeIfNotShadowed() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [(prefix: "x", uri: "urn:outer")])
		ctx.pushScope(bindings: [(prefix: "y", uri: "urn:inner")])
		#expect(ctx.resolve(prefix: "x") == "urn:outer")
		#expect(ctx.resolve(prefix: "y") == "urn:inner")
	}

	// MARK: - Pop behavior

	@Test func popRevealsShadowedBinding() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [(prefix: "x", uri: "urn:outer")])
		ctx.pushScope(bindings: [(prefix: "x", uri: "urn:inner")])
		ctx.popScope()
		#expect(ctx.resolve(prefix: "x") == "urn:outer")
	}

	@Test func popRemovesInnerBindingEntirely() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [(prefix: "x", uri: "urn:only")])
		#expect(ctx.resolve(prefix: "x") == "urn:only")
		ctx.popScope()
		#expect(ctx.resolve(prefix: "x") == nil)
	}

	@Test func popOfEmptyScopeIsBalanced() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [(prefix: "x", uri: "urn:outer")])
		ctx.pushScope(bindings: []) // empty scope — no new bindings
		#expect(ctx.resolve(prefix: "x") == "urn:outer")
		ctx.popScope()                // pop empty scope
		#expect(ctx.resolve(prefix: "x") == "urn:outer") // outer still resolves
		ctx.popScope()                // pop outer
		#expect(ctx.resolve(prefix: "x") == nil)
	}

	@Test func popWithoutPushIsNoop() {
		var ctx = XMLNamespaceContext()
		ctx.popScope() // should not crash or corrupt state
		#expect(ctx.resolve(prefix: "x") == nil)
		ctx.pushScope(bindings: [(prefix: "x", uri: "urn:x")])
		#expect(ctx.resolve(prefix: "x") == "urn:x")
	}

	// MARK: - Multiple bindings in one scope

	@Test func multipleBindingsInSameScope() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [
			(prefix: nil, uri: "http://www.w3.org/2005/Atom"),
			(prefix: "dc", uri: "http://purl.org/dc/elements/1.1/"),
			(prefix: "content", uri: "http://purl.org/rss/1.0/modules/content/")
		])
		#expect(ctx.resolve(prefix: nil) == "http://www.w3.org/2005/Atom")
		#expect(ctx.resolve(prefix: "dc") == "http://purl.org/dc/elements/1.1/")
		#expect(ctx.resolve(prefix: "content") == "http://purl.org/rss/1.0/modules/content/")
	}

	@Test func popSinglePopsAllBindingsFromThatScope() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [
			(prefix: "a", uri: "urn:a"),
			(prefix: "b", uri: "urn:b"),
			(prefix: "c", uri: "urn:c")
		])
		ctx.popScope()
		#expect(ctx.resolve(prefix: "a") == nil)
		#expect(ctx.resolve(prefix: "b") == nil)
		#expect(ctx.resolve(prefix: "c") == nil)
	}

	// MARK: - Re-binding after pop

	@Test func canPushAgainAfterPop() {
		var ctx = XMLNamespaceContext()
		ctx.pushScope(bindings: [(prefix: "x", uri: "urn:first")])
		ctx.popScope()
		ctx.pushScope(bindings: [(prefix: "x", uri: "urn:second")])
		#expect(ctx.resolve(prefix: "x") == "urn:second")
	}
}
