//
//  XMLNamespace.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

// Identifies the namespace of an element or attribute.
//
// The parser resolves each element's prefix to a URI via the xmlns bindings
// in scope, then passes this struct to the delegate. Feed parsers match on
// the URI via conveniences like `isDublinCore`.
//
// Attributes follow the XML Namespaces spec: unprefixed attributes are in
// *no* namespace (they do NOT inherit the default namespace). Unprefixed
// elements, by contrast, do inherit the default namespace if one is in scope.

public struct XMLNamespace: Sendable, Equatable, Hashable {

	/// The prefix as it appeared in the source document. nil for unprefixed
	/// elements/attributes and for the default namespace.
	public let prefix: String?

	/// The resolved namespace URI, or nil if there's no namespace in scope for this name.
	public let uri: String?

	public init(prefix: String?, uri: String?) {
		self.prefix = prefix
		self.uri = uri
	}

	// MARK: - Convenience predicates

	public var isAtom: Bool {
		uri == URI.atom
	}

	/// Dublin Core elements (`dc:`) — both the `/elements/1.1/` and `/terms/` variants.
	public var isDublinCore: Bool {
		uri == URI.dublinCore || uri == URI.dublinCoreTerms
	}

	public var isContent: Bool {
		uri == URI.content
	}

	public var isXHTML: Bool {
		uri == URI.xhtml
	}

	public var isMediaRSS: Bool {
		uri == URI.mediaRSS
	}

	public var isITunes: Bool {
		uri == URI.itunes
	}

	/// Scripting.com's `source:` namespace — used for elements like `source:markdown`
	/// in WordLand-generated feeds.
	public var isSource: Bool {
		uri == URI.source
	}

	// MARK: - Known URIs

	public enum URI {
		public static let atom = "http://www.w3.org/2005/Atom"
		public static let dublinCore = "http://purl.org/dc/elements/1.1/"
		public static let dublinCoreTerms = "http://purl.org/dc/terms/"
		public static let content = "http://purl.org/rss/1.0/modules/content/"
		public static let xhtml = "http://www.w3.org/1999/xhtml"
		public static let mediaRSS = "http://search.yahoo.com/mrss/"
		public static let itunes = "http://www.itunes.com/dtds/podcast-1.0.dtd"
		public static let source = "https://source.scripting.com/"
	}
}
