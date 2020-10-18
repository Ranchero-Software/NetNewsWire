//
//  TimelineTableRowView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit

class TimelineTableRowView : NSTableRowView {

	override var isOpaque: Bool {
		return true
	}

	override var isEmphasized: Bool {
		didSet {
			cellView?.isEmphasized = isEmphasized
		}
	}
	
	override var isSelected: Bool {
		didSet {
			cellView?.isSelected = isSelected
		}
	}
	
	init() {
		super.init(frame: NSRect.zero)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func drawBackground(in dirtyRect: NSRect) {
		NSColor.alternatingContentBackgroundColors[0].setFill()
		dirtyRect.fill()
	}

	override func drawSelection(in dirtyRect: NSRect) {
		if isEmphasized {
			NSColor.selectedContentBackgroundColor.setFill()
			dirtyRect.fill()
		} else {
			NSColor.unemphasizedSelectedContentBackgroundColor.setFill()
			dirtyRect.fill()
		}
	}
	
	private var cellView: TimelineTableCellView? {
		for oneSubview in subviews {
			if let foundView = oneSubview as? TimelineTableCellView {
				return foundView
			}
		}
		return nil
	}

}
