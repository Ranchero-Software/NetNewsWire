//
//  XMLNamespaceContext.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

// Tracks xmlns bindings as a stack of scopes.
//
// Each open element pushes a scope (possibly empty). Bindings come from the
// element's `xmlns` / `xmlns:prefix` attributes. `resolve(prefix:)` walks the
// stack looking for the most recent binding. Two predefined namespaces are
// always in scope:
//
//   xml   → http://www.w3.org/XML/1998/namespace
//   xmlns → http://www.w3.org/2000/xmlns/

struct XMLNamespaceContext {

	/// Flat list of all active bindings, newest last. `prefix == nil` is the default namespace.
	/// Scope boundaries are recorded separately in `scopeStarts` — entry `i` is the index into
	/// `bindings` where the scope pushed on the `i`-th start-tag begins.
	///
	/// This avoids allocating a per-start-tag bindings array for the overwhelming common case
	/// where an element has no xmlns declarations. Only the outer `scopeStarts` array grows,
	/// and it's a flat `[Int]`.
	private var bindings: [(prefix: String?, uri: String)] = []
	private var scopeStarts: [Int] = []

	init() {}

	/// Push a new scope and register the given bindings.
	mutating func pushScope(bindings entries: [(prefix: String?, uri: String)]) {
		scopeStarts.append(bindings.count)
		bindings.append(contentsOf: entries)
	}

	mutating func popScope() {
		guard let start = scopeStarts.popLast() else {
			return
		}
		if bindings.count > start {
			bindings.removeLast(bindings.count - start)
		}
	}

	/// Resolve a prefix to its URI, or nil if unbound.
	/// Pass `nil` to look up the default namespace.
	func resolve(prefix: String?) -> String? {
		// Built-ins.
		if prefix == "xml" {
			return "http://www.w3.org/XML/1998/namespace"
		}
		if prefix == "xmlns" {
			return "http://www.w3.org/2000/xmlns/"
		}
		// Walk active bindings from newest to oldest (most recent binding wins).
		for binding in bindings.reversed() {
			if binding.prefix == prefix {
				return binding.uri
			}
		}
		return nil
	}
}
