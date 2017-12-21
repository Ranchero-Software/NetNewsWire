//
//  NSOutlineView+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

public extension NSOutlineView {

	var selectedItems: [AnyObject] {
		get {

			if selectionIsEmpty {
				return [AnyObject]()
			}

			return selectedRowIndexes.flatMap { (oneIndex) -> AnyObject? in
				return item(atRow: oneIndex) as AnyObject
			}
		}
	}

	@IBAction func collapseSelectedRows(_ sender: Any?) {

		for item in selectedItems {
			if isExpandable(item) && isItemExpanded(item) {
				collapseItem(item)
			}
		}
	}

	@IBAction func expandSelectedRows(_ sender: Any?) {

		for item in selectedItems {
			if isExpandable(item) && !isItemExpanded(item) {
				expandItem(item)
			}
		}
	}

	@IBAction func expandAll(_ sender: Any?) {

		expandAllChildren(of: nil)
	}

	@IBAction func collapseAllExceptForGroupItems(_ sender: Any?) {

		collapseAllChildren(of: nil, exceptForGroupItems: true)
	}

	func expandAllChildren(of item: Any?) {

		guard let childItems = children(of: item) else {
			return
		}

		for child in childItems {
			if !isItemExpanded(child) && isExpandable(child) {
				expandItem(child, expandChildren: true)
			}
			expandAllChildren(of: child)
		}
	}

	func collapseAllChildren(of item: Any?, exceptForGroupItems: Bool) {

		guard let childItems = children(of: item) else {
			return
		}

		for child in childItems {
			collapseAllChildren(of: child, exceptForGroupItems: exceptForGroupItems)
			if exceptForGroupItems && isGroupItem(child) {
				continue
			}
			if isItemExpanded(child) {
				collapseItem(child, collapseChildren: true)
			}
		}
	}

	func children(of item: Any?) -> [Any]? {

		var children = [Any]()
		for indexOfItem in 0..<numberOfChildren(ofItem: item) {
			if let child = child(indexOfItem, ofItem: item) {
				children.append(child)
			}
		}
		return children.isEmpty ? nil : children
	}

	func isGroupItem(_ item: Any) -> Bool {

		return delegate?.outlineView?(self, isGroupItem: item) ?? false
	}
}
