
//
//  Container.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Articles

extension Notification.Name {
	
	public static let ChildrenDidChange = Notification.Name("ChildrenDidChange")
}

public protocol Container: AnyObject, ContainerIdentifiable {

    @MainActor var account: Account? { get }
    @MainActor var topLevelFeeds: Set<Feed> { get set }
    @MainActor var folders: Set<Folder>? { get set }
    @MainActor var externalID: String? { get set }
	
    @MainActor func hasAtLeastOneFeed() -> Bool
    @MainActor func objectIsChild(_ object: AnyObject) -> Bool

    @MainActor func hasChildFolder(with: String) -> Bool
    @MainActor func childFolder(with: String) -> Folder?

    @MainActor func removeFeed(_ feed: Feed)
    @MainActor func addFeed(_ feed: Feed)

	//Recursive — checks subfolders
    @MainActor func flattenedFeeds() -> Set<Feed>
    @MainActor func has(_ feed: Feed) -> Bool
    @MainActor func hasFeed(with feedID: String) -> Bool
    @MainActor func hasFeed(withURL url: String) -> Bool
    @MainActor func existingFeed(withFeedID: String) -> Feed?
    @MainActor func existingFeed(withURL url: String) -> Feed?
    @MainActor func existingFeed(withExternalID externalID: String) -> Feed?
    @MainActor func existingFolder(with name: String) -> Folder?
    @MainActor func existingFolder(withID: Int) -> Folder?

    @MainActor func postChildrenDidChangeNotification()
}

@MainActor public extension Container {

	func hasAtLeastOneFeed() -> Bool {
		return topLevelFeeds.count > 0
	}

	func hasChildFolder(with name: String) -> Bool {
		return childFolder(with: name) != nil
	}

	func childFolder(with name: String) -> Folder? {
		guard let folders = folders else {
			return nil
		}
		for folder in folders {
			if folder.name == name {
				return folder
			}
		}
		return nil
	}

	func objectIsChild(_ object: AnyObject) -> Bool {
		if let feed = object as? Feed {
			return topLevelFeeds.contains(feed)
		}
		if let folder = object as? Folder {
			return folders?.contains(folder) ?? false
		}
		return false
	}

	func flattenedFeeds() -> Set<Feed> {
		var feeds = Set<Feed>()
		feeds.formUnion(topLevelFeeds)
		if let folders = folders {
			for folder in folders {
				feeds.formUnion(folder.flattenedFeeds())
			}
		}
		return feeds
	}

	func hasFeed(with feedID: String) -> Bool {
		return existingFeed(withFeedID: feedID) != nil
	}

	func hasFeed(withURL url: String) -> Bool {
		return existingFeed(withURL: url) != nil
	}

	func has(_ feed: Feed) -> Bool {
		return flattenedFeeds().contains(feed)
	}
	
	func existingFeed(withFeedID feedID: String) -> Feed? {
		for feed in flattenedFeeds() {
			if feed.feedID == feedID {
				return feed
			}
		}
		return nil
	}

	func existingFeed(withURL url: String) -> Feed? {
		for feed in flattenedFeeds() {
			if feed.url == url {
				return feed
			}
		}
		return nil
	}
	
	func existingFeed(withExternalID externalID: String) -> Feed? {
		for feed in flattenedFeeds() {
			if feed.externalID == externalID {
				return feed
			}
		}
		return nil
	}

	func existingFolder(with name: String) -> Folder? {
		guard let folders = folders else {
			return nil
		}

		for folder in folders {
			if folder.name == name {
				return folder
			}
			if let subFolder = folder.existingFolder(with: name) {
				return subFolder
			}
		}
		return nil
	}

	func existingFolder(withID folderID: Int) -> Folder? {
		guard let folders = folders else {
			return nil
		}

		for folder in folders {
			if folder.folderID == folderID {
				return folder
			}
			if let subFolder = folder.existingFolder(withID: folderID) {
				return subFolder
			}
		}
		return nil
	}

	func postChildrenDidChangeNotification() {
		NotificationCenter.default.post(name: .ChildrenDidChange, object: self)
	}
}

