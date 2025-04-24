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

	func scrollTo(row: Int, extraHeight: Int = 150) {

		guard let scrollView = self.enclosingScrollView else {
			return
		}
		let documentVisibleRect = scrollView.documentVisibleRect

		let r = rect(ofRow: row)
		if NSContainsRect(documentVisibleRect, r) {
			return
		}

		let rMidY = NSMidY(r)
		var scrollPoint = NSZeroPoint;
		scrollPoint.y = floor(rMidY - (documentVisibleRect.size.height / 2.0)) + CGFloat(extraHeight)
		scrollPoint.y = max(scrollPoint.y, 0)

		let maxScrollPointY = frame.size.height - documentVisibleRect.size.height
		scrollPoint.y = min(maxScrollPointY, scrollPoint.y)

		let clipView = scrollView.contentView

		let rClipView = NSMakeRect(scrollPoint.x, scrollPoint.y, NSWidth(clipView.bounds), NSHeight(clipView.bounds))

		clipView.animator().bounds = rClipView
	}

	func scrollToRowIfNotVisible(_ row: Int) {
		if let followingRow = rowView(atRow: row, makeIfNecessary: false) {
			if !(visibleRowViews()?.contains(followingRow) ?? false) {
				scrollTo(row: row, extraHeight: 0)
			}
		} else {
			scrollTo(row: row, extraHeight: 0)
		}
	}

	func visibleRowViews() -> [NSTableRowView]? {

		guard let scrollView = self.enclosingScrollView, numberOfRows > 0 else {
			return nil
		}

		let range = rows(in: scrollView.documentVisibleRect)
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
