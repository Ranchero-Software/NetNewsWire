
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

	var account: Account? { get }
	var topLevelFeeds: Set<Feed> { get set }
	var folders: Set<Folder>? { get set }
	var externalID: String? { get set }
	
	func hasAtLeastOneWebFeed() -> Bool
	func objectIsChild(_ object: AnyObject) -> Bool

	func hasChildFolder(with: String) -> Bool
	func childFolder(with: String) -> Folder?

    func removeWebFeed(_ webFeed: Feed)
	func addFeed(_ webFeed: Feed)

	//Recursive — checks subfolders
	func flattenedFeeds() -> Set<Feed>
	func has(_ webFeed: Feed) -> Bool
	func hasWebFeed(with webFeedID: String) -> Bool
	func hasWebFeed(withURL url: String) -> Bool
	func existingWebFeed(withWebFeedID: String) -> Feed?
	func existingWebFeed(withURL url: String) -> Feed?
	func existingWebFeed(withExternalID externalID: String) -> Feed?
	func existingFolder(with name: String) -> Folder?
	func existingFolder(withID: Int) -> Folder?

	func postChildrenDidChangeNotification()
}

public extension Container {

	func hasAtLeastOneWebFeed() -> Bool {
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

	func hasWebFeed(with webFeedID: String) -> Bool {
		return existingWebFeed(withWebFeedID: webFeedID) != nil
	}

	func hasWebFeed(withURL url: String) -> Bool {
		return existingWebFeed(withURL: url) != nil
	}

	func has(_ webFeed: Feed) -> Bool {
		return flattenedFeeds().contains(webFeed)
	}
	
	func existingWebFeed(withWebFeedID webFeedID: String) -> Feed? {
		for feed in flattenedFeeds() {
			if feed.webFeedID == webFeedID {
				return feed
			}
		}
		return nil
	}

	func existingWebFeed(withURL url: String) -> Feed? {
		for feed in flattenedFeeds() {
			if feed.url == url {
				return feed
			}
		}
		return nil
	}
	
	func existingWebFeed(withExternalID externalID: String) -> Feed? {
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

