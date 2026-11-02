//
//  NSTableView+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#if os(macOS)
import AppKit

public extension NSTableView {
	var selectionIsEmpty: Bool {
		return selectedRowIndexes.startIndex == selectedRowIndexes.endIndex
	}

	func indexesOfAvailableRowsPassingTest(_ test: (Int) -> Bool) -> IndexSet? {
		// Checks visible and in-flight rows.

		var indexes = IndexSet()
		enumerateAvailableRowViews { (_, row) in
			if test(row) {
				indexes.insert(row)
			}
		}

		return indexes.isEmpty ? nil : indexes
	}

	func indexesOfAvailableRows() -> IndexSet? {
		var indexes = IndexSet()
		enumerateAvailableRowViews { indexes.insert($1) }
		return indexes.isEmpty ? nil : indexes
	}

	/// The part of the document the user can actually see. documentVisibleRect includes
	/// the area under the toolbar, under the sidebar on macOS 26, and under the header view.
	private var unobscuredDocumentRect: NSRect? {
		guard let scrollView = self.enclosingScrollView else {
			return nil
		}
		let contentInsets = scrollView.contentInsets
		let documentVisibleRect = scrollView.documentVisibleRect
		var rect = NSRect(x: documentVisibleRect.minX + contentInsets.left, y: documentVisibleRect.minY + contentInsets.top, width: documentVisibleRect.width - contentInsets.left - contentInsets.right, height: documentVisibleRect.height - contentInsets.top - contentInsets.bottom)

		// The header floats over the clip view but isn’t part of contentInsets.
		if let headerView, headerView.window != nil {
			let headerBottom = convert(headerView.bounds, from: headerView).maxY
			if headerBottom > rect.minY {
				rect.size.height = max(0, rect.maxY - headerBottom)
				rect.origin.y = headerBottom
			}
		}

		return rect
	}

	func isRowFullyVisible(_ row: Int) -> Bool {
		guard let unobscuredDocumentRect else {
			return false
		}
		return unobscuredDocumentRect.contains(rect(ofRow: row))
	}

	func scrollTo(row: Int, extraHeight: Int = 150) {
		guard let scrollView = self.enclosingScrollView, let unobscuredDocumentRect else {
			return
		}

		if isRowFullyVisible(row) {
			return
		}

		let r = rect(ofRow: row)
		// Center the row in the unobscured area, which starts obscuredTop below the clip view’s origin.
		let obscuredTop = unobscuredDocumentRect.minY - scrollView.documentVisibleRect.minY
		let rMidY = r.midY
		// extraHeight shifts the row up from center — cap it so the row stays below the header in short tables.
		let maximumExtraHeight = max(0, floor((unobscuredDocumentRect.size.height - r.height) / 2.0))
		let clampedExtraHeight = min(CGFloat(extraHeight), maximumExtraHeight)
		var scrollPoint = NSPoint.zero
		scrollPoint.y = floor(rMidY - (unobscuredDocumentRect.size.height / 2.0) - obscuredTop) + clampedExtraHeight

		let clipView = scrollView.contentView

		let rClipView = NSRect(x: scrollPoint.x, y: scrollPoint.y, width: clipView.bounds.width, height: clipView.bounds.height)

		// constrainBoundsRect clamps to the legal range, accounting for content insets.
		clipView.animator().bounds = clipView.constrainBoundsRect(rClipView)
	}

	/// A row above the visible area scrolls down just far enough to show it.
	/// A row below the visible area is centered, so the rows after it show too.
	func scrollRowFullyIntoView(_ row: Int) {
		guard let scrollView = self.enclosingScrollView, let unobscuredDocumentRect else {
			return
		}

		let r = rect(ofRow: row)
		if r.maxY > unobscuredDocumentRect.maxY {
			scrollTo(row: row, extraHeight: 0)
			return
		}
		guard r.minY < unobscuredDocumentRect.minY else {
			return
		}

		let clipView = scrollView.contentView
		var bounds = clipView.bounds
		bounds.origin.y += r.minY - unobscuredDocumentRect.minY
		clipView.animator().bounds = clipView.constrainBoundsRect(bounds)
	}

	func visibleRowViews() -> [NSTableRowView]? {
		guard let unobscuredDocumentRect, numberOfRows > 0 else {
			return nil
		}

		let range = rows(in: unobscuredDocumentRect)
		guard range.length > 0 else {
			return nil
		}
		let ixMax = numberOfRows - 1
		let ixStart = min(range.location, ixMax)
		let ixEnd = min(((range.location + range.length) - 1), ixMax)

		var visibleRows = [NSTableRowView]()

		for ixRow in ixStart...ixEnd {
			if let oneRowView = rowView(atRow: ixRow, makeIfNecessary: false) {
				visibleRows += [oneRowView]
			}
		}

		return visibleRows.isEmpty ? nil : visibleRows
	}

	func selectRow(_ row: Int) {
		self.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
	}

	func selectRowAndScrollToVisible(_ row: Int) {
		self.selectRow(row)
		self.scrollRowToVisible(row)
	}
}
#endif
