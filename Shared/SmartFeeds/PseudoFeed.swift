//
//  PseudoFeed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

#if os(macOS)

import AppKit
import Articles
import Account
import RSCore

protocol PseudoFeed: class, Feed, SmallIconProvider, PasteboardWriterOwner {

}

#else

import UIKit
import Articles
import Account
import RSCore

protocol PseudoFeed: class, Feed, SmallIconProvider {
	
}

#endif

extension PseudoFeed {
	var smallIcon: RSImage? {
		return AppAssets.smartFeedImage
	}
}
