//
//  NSOutlineView+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public extension NSOutlineView {

	var selectedItems: [AnyObject] {
		if selectionIsEmpty {
			return [AnyObject]()
		}

		return selectedRowIndexes.compactMap { (oneIndex) -> AnyObject? in
			return item(atRow: oneIndex) as AnyObject
		}
	}

	var firstSelectedRow: Int? {

		if selectionIsEmpty {
			return nil
		}
		return selectedRowIndexes.first
	}

	var lastSelectedRow: Int? {

		if selectionIsEmpty {
			return nil
		}
		return selectedRowIndexes.last
	}

	@IBAction func selectPreviousRow(_ sender: Any?) {

		guard var row = firstSelectedRow else {
			return
		}

		if row < 1 {
			return
		}
		while true {
			row -= 1
			if row < 0 {
				return
			}
			if canSelect(row) {
				selectRowAndScrollToVisible(row)
				return
			}
		}
	}

	@IBAction func selectNextRow(_ sender: Any?) {

		// If no selectedRow, end up at first selectable row.
		var row = lastSelectedRow ?? -1

		while true {
			row += 1
			if let _ = item(atRow: row) {
				if canSelect(row) {
					selectRowAndScrollToVisible(row)
					return
				}
			}
			else {
				return // if there are no more items, we’re out of rows
			}
		}
	}

	@IBAction func collapseSelectedRows(_ sender: Any?) {

		for item in selectedItems {
			if isExpandable(item) && isItemExpanded(item) {
				animator().collapseItem(item)
			}
		}
	}

	@IBAction func expandSelectedRows(_ sender: Any?) {

		for item in selectedItems {
			if isExpandable(item) && !isItemExpanded(item) {
				animator().expandItem(item)
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
				animator().expandItem(child, expandChildren: true)
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
				animator().collapseItem(child, collapseChildren: true)
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

	func canSelect(_ row: Int) -> Bool {

		guard let item = item(atRow: row) else {
			return false
		}
		return canSelectItem(item)
	}

	func canSelectItem(_ item: Any) -> Bool {

		let isSelectable = delegate?.outlineView?(self, shouldSelectItem: item) ?? true
		return isSelectable
	}
}
#endif
