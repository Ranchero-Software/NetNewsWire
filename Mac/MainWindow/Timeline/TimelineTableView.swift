//
//  TimelineTableView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/11/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore

/// Measures row heights for rows about to be shown, so they draw at their measured heights.
@MainActor protocol TimelineTableViewRowHeightDelegate: AnyObject {
	func timelineTableViewDidLayout(_ tableView: TimelineTableView)
	func timelineTableViewDidEndLiveResize(_ tableView: TimelineTableView)
}

final class TimelineTableView: NSTableView {

	weak var keyboardDelegate: KeyboardDelegate?
	weak var rowHeightDelegate: TimelineTableViewRowHeightDelegate?

	override func accessibilityLabel() -> String? {
		return NSLocalizedString("Timeline", comment: "Timeline")
	}

	// MARK: - NSResponder

	override func keyDown(with event: NSEvent) {
		if keyboardDelegate?.keydown(event, in: self) ?? false {
			return
		}
		super.keyDown(with: event)
	}

	// MARK: - NSView

	override var isOpaque: Bool {
		return true
	}

	override func layout() {
		super.layout()
		rowHeightDelegate?.timelineTableViewDidLayout(self)
	}

	override func viewDidEndLiveResize() {
		super.viewDidEndLiveResize()
		rowHeightDelegate?.timelineTableViewDidEndLiveResize(self)
	}
}
