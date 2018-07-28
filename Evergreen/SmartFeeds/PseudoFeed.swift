//
//  PseudoFeed.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Account
import RSCore

protocol PseudoFeed: class, DisplayNameProvider, UnreadCountProvider, SmallIconProvider, PasteboardWriterOwner {

}

private var smartFeedIcon: NSImage = {

	return NSImage(named: NSImage.Name.smartBadgeTemplate)!
}()

extension PseudoFeed {

	var smallIcon: NSImage? {
		return smartFeedIcon
	}
}
