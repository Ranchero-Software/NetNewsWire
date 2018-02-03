//
//  TimelineTableRowView.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit

class TimelineTableRowView : NSTableRowView {

	var cellAppearance: TimelineCellAppearance! {
		didSet {
			if cellAppearance != oldValue {
				invalidateGridRect()
			}
		}
	}
	
//	override var interiorBackgroundStyle: NSBackgroundStyle {
//		return .Light
//	}
	
	private var cellView: TimelineTableCellView? {
		get {
			for oneSubview in subviews {
				if let foundView = oneSubview as? TimelineTableCellView {
					return foundView
				}
			}
			return nil
		}
	}

	override var isEmphasized: Bool {
		didSet {
			if let cellView = cellView {
				cellView.isEmphasized = isEmphasized
			}
		}
	}

	override var isSelected: Bool {
		didSet {
			if let cellView = cellView {
				cellView.isSelected = isSelected
			}
		}
	}

	var gridRect: NSRect {
		get {
//			return NSMakeRect(floor(cellAppearance.boxLeftMargin), NSMaxY(bounds) - 1.0, NSWidth(bounds), 1)
			return NSMakeRect(0.0, NSMaxY(bounds) - 1.0, NSWidth(bounds), 1)
		}
	}
	
	override func drawSeparator(in dirtyRect: NSRect) {

		let path = NSBezierPath()
		let originX = floor(cellAppearance.boxLeftMargin)
		let destinationX = ceil(NSMaxX(bounds))
		let y = floor(NSMaxY(bounds)) - 0.5
		path.move(to: NSPoint(x: originX, y: y))
		path.line(to: NSPoint(x: destinationX, y: y))

		cellAppearance.gridColor.set()
		path.stroke()
	}

	override func draw(_ dirtyRect: NSRect) {

		super.draw(dirtyRect)

		if !isSelected && !isNextRowSelected {
			drawSeparator(in: dirtyRect)
		}
	}

	func invalidateGridRect() {
		
		setNeedsDisplay(gridRect)
	}
}
