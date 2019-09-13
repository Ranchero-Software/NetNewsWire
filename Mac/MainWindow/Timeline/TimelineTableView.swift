//
//  TimelineTableView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/11/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore

class TimelineTableView: NSTableView {
	
	weak var keyboardDelegate: KeyboardDelegate?
	
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
}
