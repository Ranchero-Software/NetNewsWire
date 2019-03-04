//
//  TimelineTableView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/11/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit

class TimelineTableView: NSTableView {
	
	weak var keyboardDelegate: KeyboardDelegate?
	
	// MARK: - NSResponder
	
	override func keyDown(with event: NSEvent) {
		if keyboardDelegate?.keydown(event, in: self) ?? false {
			return
		}
		super.keyDown(with: event)
	}
	
//	override func becomeFirstResponder() -> Bool {
//		if super.becomeFirstResponder() {
//			if selectedRow == -1 && numberOfRows > 0 {
//				rs_selectRowAndScrollToVisible(0)
//			}
//			return true
//		}
//		return false
//	}

	// MARK: - NSView

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
