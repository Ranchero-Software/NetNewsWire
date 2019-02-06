//
//  Folder.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import RSCore

public final class Folder: DisplayNameProvider, Renamable, Container, UnreadCountProvider, Hashable {


	public weak var account: Account?
	public var topLevelFeeds: Set<Feed> = Set<Feed>()
	public var folders: Set<Folder>? = nil // subfolders are not supported, so this is always nil
	
	public var name: String? {
		didSet {
			postDisplayNameDidChangeNotification()
		}
	}
	
	static let untitledName = NSLocalizedString("Untitled ƒ", comment: "Folder name")
	public let folderID: Int // not saved: per-run only
	static var incrementingID = 0

	// MARK: - DisplayNameProvider

	public var nameForDisplay: String {
		return name ?? Folder.untitledName
	}

	// MARK: - UnreadCountProvider

	public var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	// MARK: - Renamable

	public func rename(to newName: String) {
		name = newName
	}
	
	// MARK: - Init

	init(account: Account, name: String?) {
		
		self.account = account
		self.name = name

		let folderID = Folder.incrementingID
		Folder.incrementingID += 1
		self.folderID = folderID

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(childrenDidChange(_:)), name: .ChildrenDidChange, object: self)
	}

	// MARK: - Disk Dictionary

	private struct Key {
		static let name = "name"
		static let children = "children"
	}

	convenience init?(account: Account, dictionary: [String: Any]) {

		let name = dictionary[Key.name] as? String
		self.init(account: account, name: name)

		if let childrenArray = dictionary[Key.children] as? [[String: Any]] {
			self.topLevelFeeds = Folder.feedsOnly(with: childrenArray, account: account)
		}
	}

	// MARK: - Notifications

	@objc func unreadCountDidChange(_ note: Notification) {

		if let object = note.object {
			if objectIsChild(object as AnyObject) {
				updateUnreadCount()
			}
		}
	}

	@objc func childrenDidChange(_ note: Notification) {

		updateUnreadCount()
	}

	// MARK: Container

	public func flattenedFeeds() -> Set<Feed> {
		// Since sub-folders are not supported, it’s always the top-level feeds.
		return topLevelFeeds
	}

	public func objectIsChild(_ object: AnyObject) -> Bool {
		// Folders contain Feed objects only, at least for now.
		guard let feed = object as? Feed else {
			return false
		}
		return topLevelFeeds.contains(feed)
	}

	public func deleteFeed(_ feed: Feed) {
		topLevelFeeds.remove(feed)
		postChildrenDidChangeNotification()
	}

	public func deleteFolder(_ folder: Folder) {
		// Nothing to do
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(folderID)
	}

	// MARK: - Equatable

	static public func ==(lhs: Folder, rhs: Folder) -> Bool {

		return lhs === rhs
	}
}

// MARK: - Private

private extension Folder {

	func updateUnreadCount() {
		var updatedUnreadCount = 0
		for feed in topLevelFeeds {
			updatedUnreadCount += feed.unreadCount
		}
		unreadCount = updatedUnreadCount
	}

	func childrenContain(_ feed: Feed) -> Bool {
		return topLevelFeeds.contains(feed)
	}
}

// MARK: - Disk

private extension Folder {

	static func feedsOnly(with diskObjects: [[String: Any]], account: Account) -> Set<Feed> {

		// This Folder doesn’t support subfolders, but they might exist on disk.
		// (For instance: a user might manually edit the plist to add subfolders.)
		// Create a flattened version of the feeds.

		var feeds = Set<Feed>()

		for diskObject in diskObjects {

			if Feed.isFeedDictionary(diskObject) {
				if let feed = Feed(account: account, dictionary: diskObject) {
					feeds.insert(feed)
				}
			}
			else { // Folder
				if let subFolderChildren = diskObject[Key.children] as? [[String: Any]] {
					let subFolderFeeds = feedsOnly(with: subFolderChildren, account: account)
					feeds.formUnion(subFolderFeeds)
				}
			}
		}

		return feeds
	}
}

extension Folder: OPMLRepresentable {

	public func OPMLString(indentLevel: Int) -> String {

		let escapedTitle = nameForDisplay.rs_stringByEscapingSpecialXMLCharacters()
		var s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\">\n"
		s = s.rs_string(byPrependingNumberOfTabs: indentLevel)

		var hasAtLeastOneChild = false

		for feed in topLevelFeeds  {
			s += feed.OPMLString(indentLevel: indentLevel + 1)
			hasAtLeastOneChild = true
		}

		if !hasAtLeastOneChild {
			s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\"/>\n"
			s = s.rs_string(byPrependingNumberOfTabs: indentLevel)
			return s
		}

		s = s + NSString.rs_string(withNumberOfTabs: indentLevel) + "</outline>\n"

		return s
	}
}

