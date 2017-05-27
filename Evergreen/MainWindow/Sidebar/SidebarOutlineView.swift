//
//  SidebarOutlineView.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/17/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit

class SidebarOutlineView : NSOutlineView {
	
	//MARK: NSResponder
	
	override func keyDown(with event: NSEvent) {
		
		guard !event.rs_keyIsModified() else {
			super.keyDown(with: event)
			return
		}
		
		let ch = Int(event.rs_unmodifiedCharacter())
		if ch == NSNotFound {
			super.keyDown(with: event)
			return
		}
		
		var keyHandled = false
		
		switch(ch) {
			
		case NSRightArrowFunctionKey:
			keyHandled = true
			
		case NSDeleteFunctionKey:
			keyHandled = true
			Swift.print("NSDeleteFunctionKey")

		default:
			keyHandled = false
			
		}

		if keyHandled {
			NotificationCenter.default.post(name: .AppNavigationKeyPressed, object: self, userInfo: [appNavigationKey: ch])
		}

		else {
			super.keyDown(with: event)
		}
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
