//
//  TimelineTableRowView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit

class TimelineTableRowView : NSTableRowView {

	private var cellView: TimelineTableCellView? {
		for oneSubview in subviews {
			if let foundView = oneSubview as? TimelineTableCellView {
				return foundView
			}
		}
		return nil
	}

	override var isEmphasized: Bool {
		didSet {
			if #available(macOS 10.14, *) {
				return
			}
			if let cellView = cellView {
				cellView.isEmphasized = isEmphasized
			}
		}
	}

	override var isSelected: Bool {
		didSet {
			if #available(macOS 10.14, *) {
				return
			}
			if let cellView = cellView {
				cellView.isSelected = isSelected
			}
		}
	}
}
