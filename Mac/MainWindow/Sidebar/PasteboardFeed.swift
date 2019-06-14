//
//  PasteboardFeed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Articles
import Account
import RSCore

typealias PasteboardFeedDictionary = [String: String]

struct PasteboardFeed: Hashable {

	private struct Key {
		static let url = "URL"
		static let homePageURL = "homePageURL"
		static let name = "name"

		// Internal
		static let accountID = "accountID"
		static let accountType = "accountType"
		static let feedID = "feedID"
		static let editedName = "editedName"
	}

	let url: String
	let feedID: String?
	let homePageURL: String?
	let name: String?
	let editedName: String?
	let accountID: String?
	let accountType: AccountType?
	let isLocalFeed: Bool

	init(url: String, feedID: String?, homePageURL: String?, name: String?, editedName: String?, accountID: String?, accountType: AccountType?) {
		self.url = url.rs_normalizedURL()
		self.feedID = feedID
		self.homePageURL = homePageURL?.rs_normalizedURL()
		self.name = name
		self.editedName = editedName
		self.accountID = accountID
		self.accountType = accountType
		self.isLocalFeed = accountID != nil
	}

	// MARK: - Reading

	init?(dictionary: PasteboardFeedDictionary) {
		guard let url = dictionary[Key.url] else {
			return nil
		}

		let homePageURL = dictionary[Key.homePageURL]
		let name = dictionary[Key.name]
		let accountID = dictionary[Key.accountID]
		let feedID = dictionary[Key.feedID]
		let editedName = dictionary[Key.editedName]

		var accountType: AccountType? = nil
		if let accountTypeString = dictionary[Key.accountType], let accountTypeInt = Int(accountTypeString) {
			accountType = AccountType(rawValue: accountTypeInt)
		}
		
		self.init(url: url, feedID: feedID, homePageURL: homePageURL, name: name, editedName: editedName, accountID: accountID, accountType: accountType)
	}

	init?(pasteboardItem: NSPasteboardItem) {
		var pasteboardType: NSPasteboard.PasteboardType?
		if pasteboardItem.types.contains(FeedPasteboardWriter.feedUTIInternalType) {
			pasteboardType = FeedPasteboardWriter.feedUTIInternalType
		}
		else if pasteboardItem.types.contains(FeedPasteboardWriter.feedUTIType) {
			pasteboardType = FeedPasteboardWriter.feedUTIType
		}
		if let foundType = pasteboardType {
			if let feedDictionary = pasteboardItem.propertyList(forType: foundType) as? PasteboardFeedDictionary {
				self.init(dictionary: feedDictionary)
				return
			}
			return nil
		}

		// Check for URL or a string that may be a URL.
		if pasteboardItem.types.contains(.URL) {
			pasteboardType = .URL
		}
		else if pasteboardItem.types.contains(.string) {
			pasteboardType = .string
		}
		if let foundType = pasteboardType {
			if let possibleURLString = pasteboardItem.string(forType: foundType) {
				if possibleURLString.rs_stringMayBeURL() {
					self.init(url: possibleURLString, feedID: nil, homePageURL: nil, name: nil, editedName: nil, accountID: nil, accountType: nil)
					return
				}
			}
		}

		return nil
	}

	static func pasteboardFeeds(with pasteboard: NSPasteboard) -> Set<PasteboardFeed>? {
		guard let items = pasteboard.pasteboardItems else {
			return nil
		}
		let feeds = items.compactMap { PasteboardFeed(pasteboardItem: $0) }
		return feeds.isEmpty ? nil : Set(feeds)
	}

	// MARK: - Writing

	func exportDictionary() -> PasteboardFeedDictionary {
		var d = PasteboardFeedDictionary()
		d[Key.url] = url
		d[Key.homePageURL] = homePageURL ?? ""
		if let nameForDisplay = editedName ?? name {
			d[Key.name] = nameForDisplay
		}
		return d
	}

	func internalDictionary() -> PasteboardFeedDictionary {
		var d = PasteboardFeedDictionary()
		d[PasteboardFeed.Key.feedID] = feedID
		d[PasteboardFeed.Key.url] = url
		if let homePageURL = homePageURL {
			d[PasteboardFeed.Key.homePageURL] = homePageURL
		}
		if let name = name {
			d[PasteboardFeed.Key.name] = name
		}
		if let editedName = editedName {
			d[PasteboardFeed.Key.editedName] = editedName
		}
		if let accountID = accountID {
			d[PasteboardFeed.Key.accountID] = accountID
		}
		if let accountType = accountType {
			d[PasteboardFeed.Key.accountType] = String(accountType.rawValue)
		}
		return d
	}
}

extension Feed: PasteboardWriterOwner {

	public var pasteboardWriter: NSPasteboardWriting {
		return FeedPasteboardWriter(feed: self)
	}
}

@objc final class FeedPasteboardWriter: NSObject, NSPasteboardWriting {

	private let feed: Feed
	static let feedUTI = "com.ranchero.feed"
	static let feedUTIType = NSPasteboard.PasteboardType(rawValue: feedUTI)
	static let feedUTIInternal = "com.ranchero.NetNewsWire-Evergreen.internal.feed"
	static let feedUTIInternalType = NSPasteboard.PasteboardType(rawValue: feedUTIInternal)


	init(feed: Feed) {
		self.feed = feed
	}

	// MARK: - NSPasteboardWriting

	func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {

		return [FeedPasteboardWriter.feedUTIType, .URL, .string, FeedPasteboardWriter.feedUTIInternalType]
	}

	func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {

		let plist: Any?

		switch type {
		case .string:
			plist = feed.nameForDisplay
		case .URL:
			plist = feed.url
		case FeedPasteboardWriter.feedUTIType:
			plist = exportDictionary
		case FeedPasteboardWriter.feedUTIInternalType:
			plist = internalDictionary
		default:
			plist = nil
		}

		return plist
	}
}

private extension FeedPasteboardWriter {

	var pasteboardFeed: PasteboardFeed {
		return PasteboardFeed(url: feed.url, feedID: feed.feedID, homePageURL: feed.homePageURL, name: feed.name, editedName: feed.editedName, accountID: feed.account?.accountID, accountType: feed.account?.type)
	}

	var exportDictionary: PasteboardFeedDictionary {
		return pasteboardFeed.exportDictionary()
	}

	var internalDictionary: PasteboardFeedDictionary {
		return pasteboardFeed.internalDictionary()
	}
}
