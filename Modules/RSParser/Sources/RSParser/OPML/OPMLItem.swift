//
//  OPMLItem.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

// An OPML outline node — an element in the document tree.
// Leaf items (feeds) have no children and produce a non-nil `feedSpecifier`.
// Folder items have children and a nil `feedSpecifier`.
// Declared as a class because the parser and OPMLNormalizer build the tree
// by adding children to existing items — reference semantics keep that
// pattern simple.

public class OPMLItem {

	public var attributes: [String: String]?
	public private(set) var children: [OPMLItem]?

	public init(attributes: [String: String]? = nil) {
		self.attributes = attributes
	}

	public func addChild(_ child: OPMLItem) {
		if children == nil {
			children = []
		}
		children?.append(child)
	}

	/// Title resolved via OPML attribute fallback order: `title` → `text`.
	public var titleFromAttributes: String? {
		guard let attributes else {
			return nil
		}
		return attributes.opmlTitle ?? attributes.opmlText
	}

	/// True if this item has any children (i.e. represents a folder rather than a feed).
	public var isFolder: Bool {
		!(children?.isEmpty ?? true)
	}

	/// If this item has an `xmlUrl` attribute, returns a feed specifier built from
	/// the OPML attributes. Returns nil for folder items and items missing `xmlUrl`.
	public var feedSpecifier: OPMLFeedSpecifier? {
		guard let attributes, let feedURL = attributes.opmlXMLURL, !feedURL.isEmpty else {
			return nil
		}
		return OPMLFeedSpecifier(
			title: titleFromAttributes,
			feedDescription: attributes.opmlDescription,
			homePageURL: attributes.opmlHMTLURL,
			feedURL: feedURL
		)
	}
}
