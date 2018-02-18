//
//  SmartFeedPasteboardWriter.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/11/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSCore

@objc final class SmartFeedPasteboardWriter: NSObject, NSPasteboardWriting {

	private let smartFeed: PseudoFeed

	init(smartFeed: PseudoFeed) {

		self.smartFeed = smartFeed
	}

	// MARK: - NSPasteboardWriting

	func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {

		return [.string]
	}

	func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {

		let plist: Any?

		switch type {
		case .string:
			plist = smartFeed.nameForDisplay
		default:
			plist = nil
		}

		return plist
	}
}

