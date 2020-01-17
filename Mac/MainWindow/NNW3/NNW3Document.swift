//
//  NNW3Document.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

struct NNW3Document {

	private let children: [OPMLRepresentable]?

	private init(plist: [[String: AnyObject]]) {
		self.children = NNW3Folder.itemsWithPlist(plist: plist)
	}

	init?(subscriptionsPlistURL url: URL) {
		guard let data = try? Data(contentsOf: url) else {
			return nil
		}
		guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: AnyObject]] else {
			return nil
		}
		self.init(plist: plist)
	}
}

// MARK: OPMLRepresentable

extension NNW3Document: OPMLRepresentable {

	func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String {
		var s =
		"""
		<?xml version="1.0" encoding="UTF-8"?>
		<opml version="1.1">
		<head>
		<title>NetNewsWire 3 Subscriptions</title>
		</head>
		<body>

		"""

		if let children = children {
			for child in children {
				s += child.OPMLString(indentLevel: indentLevel + 1)
			}
		}

		s +=
		"""
		</body>
		</opml>
		"""

		return s
	}
}

// MARK: - NNW3Folder

private struct NNW3Folder {

	private let title: String?
	private let children: [OPMLRepresentable]?

	init(plist: [String: Any]) {
		self.title = plist["name"] as? String
		guard let childrenArray = plist["childrenArray"] as? [[String: Any]] else {
			self.children = nil
			return
		}
		self.children = NNW3Folder.itemsWithPlist(plist: childrenArray)
	}

	static func itemsWithPlist(plist: [[String: Any]]) -> [OPMLRepresentable]? {
		// Also used by NNW3Document.
		var items = [OPMLRepresentable]()
		for child in plist {
			if child["isContainer"] as? Bool ?? false {
				items.append(NNW3Folder(plist: child))
			} else {
				items.append(NNW3Feed(plist: child))
			}
		}
		return items.isEmpty ? nil : items
	}
}

// MARK: OPMLRepresentable

extension NNW3Folder: OPMLRepresentable {

	func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String {
		let t = title?.escapingSpecialXMLCharacters ?? ""
		guard let children = children else {
			// Empty folder.
			return "<outline text=\"\(t)\" title=\"\(t)\" />\n".prepending(tabCount: indentLevel)
		}

		var s = "<outline text=\"\(t)\" title=\"\(t)\">\n".prepending(tabCount: indentLevel)
		for child in children {
			s += child.OPMLString(indentLevel: indentLevel + 1)
		}

		s += "</outline>\n".prepending(tabCount: indentLevel)
		return s
	}
}

// MARK: - NNW3Feed

private struct NNW3Feed {

	private let title: String?
	private let homePageURL: String?
	private let feedURL: String?

	init(plist: [String: Any]) {
		self.title = plist["name"] as? String
		self.homePageURL = plist["home"] as? String
		self.feedURL = plist["rss"] as? String
	}
}

// MARK: OPMLRepresentable

extension NNW3Feed: OPMLRepresentable {

	func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String {
		let t = title?.escapingSpecialXMLCharacters ?? ""
		let p = homePageURL?.escapingSpecialXMLCharacters ?? ""
		let f = feedURL?.escapingSpecialXMLCharacters ?? ""

		var s = "<outline text=\"\(t)\" title=\"\(t)\" description=\"\" type=\"rss\" version=\"RSS\" htmlUrl=\"\(p)\" xmlUrl=\"\(f)\"/>\n"
		s = s.prepending(tabCount: indentLevel)

		return s
	}
}

