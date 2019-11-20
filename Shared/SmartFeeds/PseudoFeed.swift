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

private var smartFeedIcon: RSImage = {
	return RSImage(named: NSImage.smartBadgeTemplateName)!
}()

extension PseudoFeed {

	var smallIcon: RSImage? {
		return smartFeedIcon
	}
}
#else

import Foundation
import Articles
import Account
import RSCore

protocol PseudoFeed: class, Feed, SmallIconProvider {
	
}

private var smartFeedIcon: UIImage = {
	return AppAssets.smartFeedImage
}()

extension PseudoFeed {
	var smallIcon: UIImage? {
		return smartFeedIcon
	}
}

#endif
