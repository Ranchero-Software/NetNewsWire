//
//  NSOutlineView+RSTree.swift
//  RSTree
//
//  Created by Brent Simmons on 9/5/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#if os(OSX)

import AppKit

public extension NSOutlineView {

	@discardableResult
	func revealAndSelectNodeAtPath(_ nodePath: NodePath) -> Bool {

		// Returns true on success. Expands folders on the way. May succeed partially (returns false, in that case).

		let numberOfNodes = nodePath.components.count
		if numberOfNodes < 2 {
			return false
		}
		
		let indexOfNodeToSelect = numberOfNodes - 1

		for i in 1...indexOfNodeToSelect { // Start at 1 to skip root node.

			let oneNode = nodePath.components[i]
			let oneRow = row(forItem: oneNode)
			if oneRow < 0 {
				return false
			}

			if i == indexOfNodeToSelect {
				selectRowIndexes(NSIndexSet(index: oneRow) as IndexSet, byExtendingSelection: false)
				scrollRowToVisible(oneRow)
				return true
			}
			else {
				expandItem(oneNode)
			}
		}

		return false
	}

	@discardableResult
	func revealAndSelectRepresentedObject(_ representedObject: AnyObject, _ treeController: TreeController) -> Bool {

		guard let nodePath = NodePath(representedObject: representedObject, treeController: treeController) else {
			return false
		}
		return revealAndSelectNodeAtPath(nodePath)
	}
}

#endif
