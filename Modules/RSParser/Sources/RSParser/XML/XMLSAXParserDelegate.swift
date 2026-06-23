//
//  XMLSAXParserDelegate.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

// Pure-Swift streaming XML parser delegate protocol.
//
// Byte slices throughout for tag/content bytes. Element and attribute
// namespaces come as a single XMLNamespace struct (prefix + resolved URI)
// with convenience predicates like `isDublinCore`, `isAtom`, etc.
//
// All callbacks happen on the thread that called `XMLSAXParser.parse(_:)`.
// Not re-entrant.
//
// All methods are default-implemented (empty). Consumers only implement
// what they care about.

public protocol XMLSAXParserDelegate: AnyObject {

	/// Called on each start tag (including self-closing — which also get a matching end).
	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didStartElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace,
	                  attributes: XMLAttributes)

	/// Called on each end tag.
	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didEndElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace)

	/// Called for each run of character content (entity references expanded).
	/// Length is always ≥ 1.
	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didFindCharacters bytes: ArraySlice<UInt8>)

	/// Called when the parser, at the delegate's request, captured the raw inner bytes
	/// of an element — everything between the start tag's `>` and the matching end
	/// tag's `<`, verbatim from the input. No intermediate start/end/characters
	/// callbacks are delivered for children.
	///
	/// Request this mode by calling `parser.captureRawInnerContent()` from inside
	/// `didStartElement`. Useful when the consumer wants the content as a string
	/// (e.g. Atom `<content type="xhtml">`), where reconstructing markup from SAX
	/// events would be redundant and subtly lossy.
	///
	/// `bytes` is an `ArraySlice` view into the parser's input buffer — copy if you
	/// need to keep it beyond this callback. The outer element's `didEndElement` is
	/// delivered immediately after this call.
	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didCaptureRawInnerContent bytes: ArraySlice<UInt8>,
	                  forElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace)

	/// Called once when parsing reaches end of document.
	func xmlSAXParserDidEnd(_ parser: XMLSAXParser)
}

public extension XMLSAXParserDelegate {

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didStartElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace,
	                  attributes: XMLAttributes) {}

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didEndElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace) {}

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didFindCharacters bytes: ArraySlice<UInt8>) {}

	func xmlSAXParser(_ parser: XMLSAXParser,
	                  didCaptureRawInnerContent bytes: ArraySlice<UInt8>,
	                  forElement localName: ArraySlice<UInt8>,
	                  namespace: XMLNamespace) {}

	func xmlSAXParserDidEnd(_ parser: XMLSAXParser) {}
}
