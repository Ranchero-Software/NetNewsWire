//
//  TimelineTableView.swift
//  Evergreen
//
//  Created by Brent Simmons on 10/11/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

class TimelineTableView: NSTableView {
	
	@IBOutlet var keyboardDelegate: KeyboardDelegate!
	
	//MARK: NSResponder
	
	override func keyDown(with event: NSEvent) {

		if keyboardDelegate.keydown(event, in: self) {
			return
		}
		super.keyDown(with: event)
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

	func redrawGrid() {

		guard let rowViews = visibleRowViews() else {
			return
		}

		rowViews.forEach{ (rowView) in
			if let rowView = rowView as? TimelineTableRowView {
				rowView.invalidateGridRect()
			}
		}
	}
}
