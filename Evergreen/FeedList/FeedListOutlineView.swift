//
//  FeedListOutlineView.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/11/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSTree

final class FeedListOutlineView: NSOutlineView {

	override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {

		// Adjust top-level cells — they were too close to the disclosure indicator.

		var frame = super.frameOfCell(atColumn: column, row: row)

		let node = item(atRow: row) as! Node
		guard let parentNode = node.parent, parentNode.isRoot else {
			return frame
		}

		let adjustment: CGFloat = 4.0
		frame.origin.x += adjustment
		frame.size.width -= adjustment
		return frame
	}
}
