//
//  LocalFolder.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Data

let folderIDKey = "folderID"
private let folderNameKey = "name"

// LocalFolders can contain LocalFeeds only. Sub-folders are not allowed.

public final class LocalFolder: Folder, PlistProvider {

	public var nameForDisplay: String
	public let account: Account?

	public var feeds = [String: LocalFeed]()
	let folderID: String

	public var unreadCount = 0 {
		didSet {
			postUnreadCountDidChangeNotification()
		}
	}

	public var plist: AnyObject? {
		get {
			return createDiskDictionary()
		}
	}

	init(nameForDisplay: String, folderID: String, account: Account) {

		self.nameForDisplay = nameForDisplay
		self.folderID = folderID
		self.account = account
	}

	convenience init(nameForDisplay: String, account: Account) {

		self.init(nameForDisplay: nameForDisplay, folderID: uniqueIdentifier(), account: account)
	}

	// MARK: Folder

	public var hasAtLeastOneFeed: Bool {
		get {
			return !feeds.isEmpty
		}
	}

	public var flattenedFeeds: NSSet {
		get {
			return Set(feeds.values) as NSSet
		}
	}

	public var flattenedFeedIDs: Set<String> {
		get {
			
			return Set(feeds.keys)
		}
	}
	
	public func fetchArticles() -> [Article] {
		
		if let account = account as? LocalAccount {
			let articlesSet = account.fetchArticlesForFolder(self)
			return articlesSet.map { $0 as Article }
		}
		return [Article]()
	}
	
	public func objectIsChild(_ obj: AnyObject) -> Bool {

		if let feed = obj as? LocalFeed {
			return feeds[feed.feedID] != nil
		}
		return false
	}

	public func objectIsDescendant(_ obj: AnyObject) -> Bool {

		return objectIsChild(obj)
	}

	public func visitObjects(_ recurse: Bool, visitBlock: FolderVisitBlock) -> Bool {

		for oneFeed in feeds.values {
			if visitBlock(oneFeed) {
				return true
			}
		}
		return false
	}

	public func existingFeedWithID(_ feedID: String) -> Feed? {

		return feeds[feedID] as Feed?
	}

	public func existingFeedWithURL(_ urlString: String) -> Feed? {
		
		return feeds[urlString] as Feed?
	}
	
	public func existingFolderWithName(_ name: String) -> Folder? {

		return nil
	}

	public func canAddItem(_ item: AnyObject) -> Bool {

		return item is LocalFeed
	}

	public func addItem(_ item: AnyObject) -> Bool {

		guard let feed = item as? LocalFeed else {
			return false
		}

		if let _ = existingFeedWithID(feed.feedID) {
			return true
		}
		feeds[feed.feedID] = feed
		FolderPostChildrenDidChangeNotification(self)
		
		return true
	}

	public func canAddFolderWithName(_ folderName: String) -> Bool {
		
		return false
	}
	
	public func ensureFolderWithName(_ folderName: String) -> Folder? {
		
		return nil
	}

	public func createFeedWithName(_ name: String?, editedName: String?, urlString: String) -> Feed? {

		return account?.createFeedWithName(name, editedName: editedName, urlString: urlString)
	}

	public func deleteItems(_ items: [AnyObject]) {

		deleteFeeds(feedsWithItems(items))
		FolderPostChildrenDidChangeNotification(self)
		updateUnreadCount()
	}

	// MARK: UnreadCountProvider

	public func updateUnreadCount() {

		let updatedUnreadCount = calculateUnreadCount(feeds.values)
		if updatedUnreadCount != unreadCount {
			unreadCount = updatedUnreadCount
		}
	}
}

// MARK: Disk

extension LocalFolder {

	convenience init?(account: LocalAccount, diskDictionary: NSDictionary) {

		guard let folderID = diskDictionary[folderIDKey] as? String else {
			return nil
		}
		guard let folderName = diskDictionary[folderNameKey] as? String else {
			return nil
		}
		self.init(nameForDisplay: folderName, folderID: folderID, account: account as Account)

		if let childrenDiskArray = diskDictionary[diskDictionaryChildrenKey] as? NSArray {

			let childrenArray = account.childrenForDiskArray(childrenDiskArray)
			childrenArray.forEach{ (oneItem) in
				if let oneFeed = oneItem as? LocalFeed {
					feeds[oneFeed.feedID] = oneFeed
				}
			}
		}
	}
}

// MARK: Private

private extension LocalFolder {

	func createDiskDictionary() -> NSDictionary {

		let d = NSMutableDictionary()

		d.setObjectWithStringKey(folderID as NSString, folderIDKey)
		d.setObjectWithStringKey(nameForDisplay as NSString, folderNameKey)

		if unreadCount > 0 {
			d.setObjectWithStringKey(NSNumber(value: unreadCount), unreadCountKey)
		}
		
		let children = NSMutableArray()
		feeds.values.forEach { (oneLocalFeed) in
			if let onePlist = oneLocalFeed.plist {
				children.add(onePlist)
			}
		}
		if children.count > 0 {
			d.setObjectWithStringKey(children, diskDictionaryChildrenKey)
		}

		return d
	}

	func feedsWithItems(_ items: [AnyObject]) -> [LocalFeed] {

		return items.flatMap { $0 as? LocalFeed	}
	}

	func deleteFeeds(_ feeds: [LocalFeed]) {

		feeds.forEach { deleteFeed($0) }
	}

	func deleteFeed(_ feed: LocalFeed) {

		feeds[feed.feedID] = nil
	}
}

