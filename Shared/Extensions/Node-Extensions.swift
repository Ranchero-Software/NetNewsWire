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
import RSCore

public enum SourceListOrdering: Int {
	case alphabetically = 1
	case foldersFirst = 2
	case topLevelFeedsFirst = 3
}

extension Array where Element == Node {

	func sortedAlphabeticallyWith(_ ordering: SourceListOrdering) -> [Node] {
		return Node.nodesSortedAlphabeticallyWith(ordering, nodes: self)
	}
	
	func sortedAlphabetically() -> [Node] {

		return Node.nodesSortedAlphabetically(self)
	}
	
	func sortedAlphabeticallyWithFoldersAtTop() -> [Node] {

		return Node.nodesSortedAlphabeticallyWithFoldersAtTop(self)
	}

	func sortedAlphabeticallyWithFoldersAtEnd() -> [Node] {

		return Node.nodesSortedAlphabeticallyWithFoldersAtEnd(self)
	}
}

private extension Node {

	class func nodesSortedAlphabeticallyWith(_ ordering: SourceListOrdering, nodes : [Node]) -> [Node] {
		return nodes.sorted { (node1, node2) -> Bool in
			
			if ordering != .alphabetically && node1.canHaveChildNodes != node2.canHaveChildNodes {
				if node1.canHaveChildNodes {
					return ordering == .foldersFirst
				}
				return ordering != .foldersFirst
			}
			
			guard let obj1 = node1.representedObject as? DisplayNameProvider, let obj2 = node2.representedObject as? DisplayNameProvider else {
				return false
			}
			
			let name1 = obj1.nameForDisplay
			let name2 = obj2.nameForDisplay
			
			return name1.localizedStandardCompare(name2) == .orderedAscending
		}
	}
	
	class func nodesSortedAlphabetically(_ nodes: [Node]) -> [Node] {
		
		return nodesSortedAlphabeticallyWith(.alphabetically, nodes: nodes)
	}
		
	class func nodesSortedAlphabeticallyWithFoldersAtEnd(_ nodes: [Node]) -> [Node] {
		
		return nodesSortedAlphabeticallyWith(.topLevelFeedsFirst, nodes: nodes)
	}
	
	class func nodesSortedAlphabeticallyWithFoldersAtTop(_ nodes: [Node]) -> [Node] {
		
		return nodesSortedAlphabeticallyWith(.foldersFirst, nodes: nodes)
	}

}

