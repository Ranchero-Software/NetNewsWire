//
//  TimelineTableView.swift
//  Evergreen
//
//  Created by Brent Simmons on 10/11/16.
//  Copyright © 2016 Ranchero Software. All rights reserved.
//

import Cocoa

class TimelineTableView: NSTableView {
	
	weak var keyboardDelegate: KeyboardDelegate?
	
	//MARK: NSResponder
	
	override func keyDown(with event: NSEvent) {
		
		if let keyboardDelegate = keyboardDelegate {
			if keyboardDelegate.handleKeydownEvent(event, sender: self) {
				return;
			}
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

}
