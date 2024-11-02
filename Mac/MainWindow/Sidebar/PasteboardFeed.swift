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
		self.url = url.normalizedURL
		self.feedID = feedID
		self.homePageURL = homePageURL?.normalizedURL
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
		if pasteboardItem.types.contains(WebFeedPasteboardWriter.webFeedUTIInternalType) {
			pasteboardType = WebFeedPasteboardWriter.webFeedUTIInternalType
		}
		else if pasteboardItem.types.contains(WebFeedPasteboardWriter.webFeedUTIType) {
			pasteboardType = WebFeedPasteboardWriter.webFeedUTIType
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
				if possibleURLString.mayBeURL {
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
		let webFeeds = items.compactMap { PasteboardFeed(pasteboardItem: $0) }
		return webFeeds.isEmpty ? nil : Set(webFeeds)
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

extension Feed: @retroactive PasteboardWriterOwner {

	public var pasteboardWriter: NSPasteboardWriting {
		return WebFeedPasteboardWriter(webFeed: self)
	}
}

@objc final class WebFeedPasteboardWriter: NSObject, NSPasteboardWriting {

	private let webFeed: Feed
	static let webFeedUTI = "com.ranchero.webFeed"
	static let webFeedUTIType = NSPasteboard.PasteboardType(rawValue: webFeedUTI)
	static let webFeedUTIInternal = "com.ranchero.NetNewsWire-Evergreen.internal.webFeed"
	static let webFeedUTIInternalType = NSPasteboard.PasteboardType(rawValue: webFeedUTIInternal)


	init(webFeed: Feed) {
		self.webFeed = webFeed
	}

	// MARK: - NSPasteboardWriting

	func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {

		return [WebFeedPasteboardWriter.webFeedUTIType, .URL, .string, WebFeedPasteboardWriter.webFeedUTIInternalType]
	}

	func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {

		let plist: Any?

		switch type {
		case .string:
			plist = webFeed.nameForDisplay
		case .URL:
			plist = webFeed.url
		case WebFeedPasteboardWriter.webFeedUTIType:
			plist = exportDictionary
		case WebFeedPasteboardWriter.webFeedUTIInternalType:
			plist = internalDictionary
		default:
			plist = nil
		}

		return plist
	}
}

private extension WebFeedPasteboardWriter {

	var pasteboardFeed: PasteboardFeed {
		return PasteboardFeed(url: webFeed.url, feedID: webFeed.webFeedID, homePageURL: webFeed.homePageURL, name: webFeed.name, editedName: webFeed.editedName, accountID: webFeed.account?.accountID, accountType: webFeed.account?.type)
	}

	var exportDictionary: PasteboardFeedDictionary {
		return pasteboardFeed.exportDictionary()
	}

	var internalDictionary: PasteboardFeedDictionary {
		return pasteboardFeed.internalDictionary()
	}
}
