//
//  Node-Extensions.swift
//  Local
//
//  Created by Brent Simmons on 8/10/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSTree
import Articles
import Account
import RSCore

@MainActor extension Array where Element == Node {

	func sortedAlphabetically() -> [Node] {

		return Node.nodesSortedAlphabetically(self)
	}

	func sortedAlphabeticallyWithFoldersAtEnd() -> [Node] {

		return Node.nodesSortedAlphabeticallyWithFoldersAtEnd(self)
	}

	/// Sidebar order: feeds first (by `Feed.sortIndex`, then alphabetically), folders last (alphabetically).
	/// When every feed has the default `sortIndex` of 0 this is identical to `sortedAlphabeticallyWithFoldersAtEnd()`.
	func sortedByFeedOrderWithFoldersAtEnd() -> [Node] {

		return Node.nodesSortedByFeedOrderWithFoldersAtEnd(self)
	}
}

@MainActor private extension Node {

	class func nodesSortedAlphabetically(_ nodes: [Node]) -> [Node] {

		return nodes.sorted { (node1, node2) -> Bool in

			guard let obj1 = node1.representedObject as? DisplayNameProvider, let obj2 = node2.representedObject as? DisplayNameProvider else {
				return false
			}

			let name1 = obj1.nameForDisplay
			let name2 = obj2.nameForDisplay

			return name1.localizedStandardCompare(name2) == .orderedAscending
		}
	}

	class func nodesSortedAlphabeticallyWithFoldersAtEnd(_ nodes: [Node]) -> [Node] {

		return nodes.sorted { (node1, node2) -> Bool in

			if node1.canHaveChildNodes != node2.canHaveChildNodes {
				if node1.canHaveChildNodes {
					return false
				}
				return true
			}

			guard let obj1 = node1.representedObject as? DisplayNameProvider, let obj2 = node2.representedObject as? DisplayNameProvider else {
				return false
			}

			let name1 = obj1.nameForDisplay
			let name2 = obj2.nameForDisplay

			return name1.localizedStandardCompare(name2) == .orderedAscending
		}
	}

	class func nodesSortedByFeedOrderWithFoldersAtEnd(_ nodes: [Node]) -> [Node] {

		return nodes.sorted { (node1, node2) -> Bool in

			if node1.canHaveChildNodes != node2.canHaveChildNodes {
				if node1.canHaveChildNodes {
					return false
				}
				return true
			}

			if let feed1 = node1.representedObject as? Feed, let feed2 = node2.representedObject as? Feed, feed1.sortIndex != feed2.sortIndex {
				return feed1.sortIndex < feed2.sortIndex
			}

			guard let obj1 = node1.representedObject as? DisplayNameProvider, let obj2 = node2.representedObject as? DisplayNameProvider else {
				return false
			}

			let name1 = obj1.nameForDisplay
			let name2 = obj2.nameForDisplay

			return name1.localizedStandardCompare(name2) == .orderedAscending
		}
	}
}
