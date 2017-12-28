//
//  FeedListWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

class FeedListWindowController : NSWindowController {
    

	public convenience init() {

		self.init(windowNibName: NSNib.Name(rawValue: "FeedListWindow"))
	}

	@IBAction func addToFeeds(_ sender: AnyObject) {

	}

	@IBAction func openHomePage(_ sender: AnyObject) {

	}
}


