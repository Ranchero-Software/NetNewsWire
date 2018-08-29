//
//  SidebarOutlineView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/17/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import RSTree

class SidebarOutlineView : NSOutlineView {

	@IBOutlet var keyboardDelegate: KeyboardDelegate!

	// MARK: NSTableView

	override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {

		// Don’t allow the pseudo-feeds at the top level to be indented.

		var frame = super.frameOfCell(atColumn: column, row: row)
		frame.origin.x += 4.0
		frame.size.width -= 4.0

		let node = item(atRow: row) as! Node
		guard let parentNode = node.parent, parentNode.isRoot else {
			return frame
		}
		guard node.representedObject is PseudoFeed else {
			return frame
		}

		frame.origin.x -= indentationPerLevel
		frame.size.width += indentationPerLevel
		return frame
	}

	// MARK: NSView

	override func viewWillStartLiveResize() {
		
		if let scrollView = self.enclosingScrollView {
			scrollView.hasVerticalScroller = false
		}
		super.viewWillStartLiveResize()
	}
	
	override func viewDidEndLiveResize() {
		
		if let scrollView = self.enclosingScrollView {
			scrollView.hasVerticalScroller = true
		}
		super.viewDidEndLiveResize()
	}

	// MARK: NSResponder

	override func keyDown(with event: NSEvent) {

		if keyboardDelegate.keydown(event, in: self) {
			return
		}

		super.keyDown(with: event)
	}
}
