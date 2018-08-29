//
//  FeedListWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit

class FeedListWindowController : NSWindowController {
    
	override func windowDidLoad() {

//		window!.appearance = NSAppearance(named: .vibrantDark)

		let windowAutosaveName = NSWindow.FrameAutosaveName(rawValue: "FeedDirectoryWindow")
		window?.setFrameUsingName(windowAutosaveName, force: true)
	}
}


