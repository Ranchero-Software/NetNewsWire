//
//  Folder.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Data
import RSCore

public final class Folder: DisplayNameProvider, Container, UnreadCountProvider, Hashable {    

	public weak var account: Account?
	public var children = [AnyObject]()

	public var name: String? {
		didSet {
			postDisplayNameDidChangeNotification()
		}
	}
	
	static let untitledName = NSLocalizedString("Untitled ƒ", comment: "Folder name")
	public let folderID: Int // not saved: per-run only
	static var incrementingID = 0
	public let hashValue: Int

	// MARK: - Fetching Articles
	
	public func fetchArticles() -> Set<Article> {

		guard let account = account else {
			return Set<Article>()
		}
		return account.fetchArticles(folder: self)
	}
	
	// MARK: - DisplayNameProvider

	public var nameForDisplay: String {
		get {
			return name ?? Folder.untitledName

		}
	}

	// MARK: - UnreadCountProvider

	public var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	// MARK: - Init

	init(account: Account, name: String?) {
		
		self.account = account
		self.name = name

		let folderID = Folder.incrementingID
		Folder.incrementingID += 1
		self.folderID = folderID
		self.hashValue = folderID

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
	}

	// MARK: - Disk Dictionary

	private struct Key {
		static let name = "name"
		static let unreadCount = "unreadCount"
		static let children = "children"
	}

	convenience init?(account: Account, dictionary: [String: Any]) {

		let name = dictionary[Key.name] as? String
		self.init(account: account, name: name)

		if let childrenArray = dictionary[Key.children] as? [[String: Any]] {
			self.children = Folder.objects(with: childrenArray, account: account)
		}

		if let savedUnreadCount = dictionary[Key.unreadCount] as? Int {
			self.unreadCount = savedUnreadCount
		}
	}

	var dictionary: [String: Any] {
		get {

			var d = [String: Any]()
			guard let account = account else {
				return d
			}

			if let name = name {
				d[Key.name] = name
			}
			if unreadCount > 0 {
				d[Key.unreadCount] = unreadCount
			}

			let childObjects = children.compactMap { (child) -> [String: Any]? in

				if let feed = child as? Feed {
					return feed.dictionary
				}
				if let folder = child as? Folder, account.supportsSubFolders {
					return folder.dictionary
				}
				assertionFailure("Expected a feed or a folder.");
				return nil
			}

			if !childObjects.isEmpty {
				d[Key.children] = childObjects
			}

			return d
		}
	}
	
	// MARK: Feeds
	
	func addFeed(_ feed: Feed) -> Bool {
		
		// Return true in the case where the feed is already a child.
		
		if !childrenContain(feed) {
			children += [feed]
			postChildrenDidChangeNotification()
		}
		return true
	}
    
	// MARK: Notifications

	@objc func unreadCountDidChange(_ note: Notification) {

		if let object = note.object {
			if objectIsChild(object as AnyObject) {
				updateUnreadCount()
			}
		}
	}

	// MARK: - Equatable

	static public func ==(lhs: Folder, rhs: Folder) -> Bool {

		return lhs === rhs
	}
}

// MARK: - Private

private extension Folder {

	func updateUnreadCount() {
		
		unreadCount = calculateUnreadCount(children)
	}

	func childrenContain(_ feed: Feed) -> Bool {
		
		return children.contains(where: { (object) -> Bool in
			if object === feed {
				return true
			}
			if let oneFeed = object as? Feed {
				if oneFeed.feedID == feed.feedID {
					assertionFailure("Expected feeds to match by pointer equality rather than by feedID.")
					return true
				}
			}
			return false
		})
	}
}

// MARK: - Disk

private extension Folder {

	static func objects(with diskObjects: [[String: Any]], account: Account) -> [AnyObject] {

		if account.supportsSubFolders {
			return account.objects(with: diskObjects)
		}
		else {
			let flattenedFeeds = feedsOnly(with: diskObjects, account: account)
			return Array(flattenedFeeds) as [AnyObject]
		}
	}

	static func feedsOnly(with diskObjects: [[String: Any]], account: Account) -> Set<Feed> {

		// This Folder doesn’t support subfolders, but they might exist on disk.
		// (For instance: a user might manually edit the plist to add subfolders.)
		// Create a flattened version of the feeds.

		var feeds = Set<Feed>()

		for diskObject in diskObjects {

			if Feed.isFeedDictionary(diskObject) {
				if let feed = Feed(accountID: account.accountID, dictionary: diskObject) {
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

		for child in children  {
			if let opmlObject = child as? OPMLRepresentable {
				s += opmlObject.OPMLString(indentLevel: indentLevel + 1)
				hasAtLeastOneChild = true
			}
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

