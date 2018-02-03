//
//  FeedPasteboardWriter.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/7/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import Data

@objc final class FeedPasteboardWriter: NSObject, NSPasteboardWriting {

	private let feed: Feed
	static let feedUTI = "com.ranchero.feed"
	static let feedUTIType = NSPasteboard.PasteboardType(rawValue: feedUTI)
	static let feedUTIInternal = "com.ranchero.evergreen.internal.feed"
	static let feedUTIInternalType = NSPasteboard.PasteboardType(rawValue: feedUTIInternal)

	init(feed: Feed) {

		self.feed = feed
	}

	// MARK: - NSPasteboardWriting

	func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {

		return [.string, .URL, FeedPasteboardWriter.feedUTIType, FeedPasteboardWriter.feedUTIInternalType]
	}

	func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {

		let plist: Any?

		switch type {
		case .string:
			plist = feed.nameForDisplay
		case .URL:
			plist = feed.url
		case FeedPasteboardWriter.feedUTIType:
			plist = exportDictionary()
		case FeedPasteboardWriter.feedUTIInternalType:
			plist = internalDictionary()
		default:
			plist = nil
		}

		return plist
	}
}

private extension FeedPasteboardWriter {

	private struct Key {

		static let url = "URL"
		static let homePageURL = "homePageURL"
		static let name = "name"

		// Internal
		static let accountID = "accountID"
		static let feedID = "feedID"
		static let editedName = "editedName"
		static let unreadCount = "unreadCount"
	}

	func exportDictionary() -> [String: String] {

		var d = [String: String]()

		d[Key.url] = feed.url
		d[Key.homePageURL] = feed.homePageURL ?? ""
		d[Key.name] = feed.nameForDisplay

		return d
	}

	func internalDictionary() -> [String: Any] {

		var d = [String: Any]()

		d[Key.url] = feed.url
		if let homePageURL = feed.homePageURL {
			d[Key.homePageURL] = homePageURL
		}
		if let name = feed.name {
			d[Key.name] = name
		}
		if let editedName = feed.editedName {
			d[Key.editedName] = editedName
		}
		if feed.unreadCount > 0 {
			d[Key.unreadCount] = feed.unreadCount
		}

		return d

	}
}
