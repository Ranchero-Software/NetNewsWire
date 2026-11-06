//
//  TimelineTableRowView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit

final class TimelineTableRowView: NSTableRowView {

	/// The last row has no separator below it.
	var isLastRow = false {
		didSet {
			if isLastRow != oldValue {
				needsDisplay = true
			}
		}
	}

	private static let separatorInsetLeft: CGFloat = 20.0
	private static let separatorInsetRight: CGFloat = 4.0
	private static let separatorHeight: CGFloat = 1.0

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

	private var cellView: TimelineTableCellView? {
		for oneSubview in subviews {
			if let foundView = oneSubview as? TimelineTableCellView {
				return foundView
			}
		}
		return nil
	}

	/// Called only when the table’s `gridStyleMask` includes horizontal lines. Inset to line up with the cell’s content.
	override func drawSeparator(in dirtyRect: NSRect) {
		guard !isLastRow, !isSelected, let cellView else {
			return
		}
		let separatorRect = NSRect(x: cellView.frame.minX + Self.separatorInsetLeft, y: bounds.maxY - Self.separatorHeight, width: cellView.frame.width - Self.separatorInsetLeft - Self.separatorInsetRight, height: Self.separatorHeight)
		let gridColor = (superview as? NSTableView)?.gridColor ?? .gridColor
		gridColor.setFill()
		separatorRect.fill(using: .sourceOver)
	}
}
