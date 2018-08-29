
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

public protocol Container: class {

	var children: [AnyObject] { get set }

	func hasAtLeastOneFeed() -> Bool
	func objectIsChild(_ object: AnyObject) -> Bool

	func hasChildFolder(with: String) -> Bool
	func childFolder(with: String) -> Folder?

    func deleteFeed(_ feed: Feed)
    func deleteFolder(_ folder: Folder)
    
	//Recursive
	func flattenedFeeds() -> Set<Feed>
	func hasFeed(with feedID: String) -> Bool
	func hasFeed(withURL url: String) -> Bool
	func existingFeed(with feedID: String) -> Feed?
	func existingFeed(withURL url: String) -> Feed?
	func existingFolder(with name: String) -> Folder?
	func existingFolder(withID: Int) -> Folder?

	func postChildrenDidChangeNotification()
}

public extension Container {

	func hasAtLeastOneFeed() -> Bool {

		for child in children {
			if child is Feed {
				return true
			}
			if let folder = child as? Folder {
				if folder.hasAtLeastOneFeed() {
					return true
				}
			}
		}

		return false
	}

	func hasChildFolder(with name: String) -> Bool {

		return childFolder(with: name) != nil
	}

	func childFolder(with name: String) -> Folder? {

		for child in children {
			if let folder = child as? Folder, folder.name == name {
				return folder
			}
		}

		return nil
	}

	func objectIsChild(_ object: AnyObject) -> Bool {

		for child in children {
			if object === child {
				return true
			}
		}
		return false
	}

	func flattenedFeeds() -> Set<Feed> {

		var feeds = Set<Feed>()

		for object in children {
			if let feed = object as? Feed {
				feeds.insert(feed)
			}
			else if let container = object as? Container {
				feeds.formUnion(container.flattenedFeeds())
			}
		}

		return feeds
	}

	func hasFeed(with feedID: String) -> Bool {

		return existingFeed(with: feedID) != nil
	}

	func hasFeed(withURL url: String) -> Bool {

		return existingFeed(withURL: url) != nil
	}

	func existingFeed(with feedID: String) -> Feed? {

		for child in children {

			if let feed = child as? Feed, feed.feedID == feedID {
				return feed
			}
			if let container = child as? Container, let feed = container.existingFeed(with: feedID) {
				return feed
			}
		}

		return nil
	}

	func existingFeed(withURL url: String) -> Feed? {

		for child in children {

			if let feed = child as? Feed, feed.url == url {
				return feed
			}
			if let container = child as? Container, let feed = container.existingFeed(withURL: url) {
				return feed
			}
		}

		return nil
	}

	func existingFolder(with name: String) -> Folder? {

		for child in children {

			if let folder = child as? Folder {
				if folder.name == name {
					return folder
				}
				if let subFolder = folder.existingFolder(with: name) {
					return subFolder
				}
			}
		}

		return nil
	}

	func existingFolder(withID folderID: Int) -> Folder? {

		for child in children {

			if let folder = child as? Folder {
				if folder.folderID == folderID {
					return folder
				}
				if let subFolder = folder.existingFolder(withID: folderID) {
					return subFolder
				}
			}
		}

		return nil
	}

    func indexOf<T: Equatable>(_ object: T) -> Int? {
        
        return children.index(where: { (child) -> Bool in
            if let oneObject = child as? T {
                return oneObject == object
            }
            return false
        })
    }
    
    func delete<T: Equatable>(_ object: T) {
        
        if let index = indexOf(object) {
            children.remove(at: index)
            postChildrenDidChangeNotification()
        }
    }
    
    func deleteFeed(_ feed: Feed) {
        
        return delete(feed)
    }
    
    func deleteFolder(_ folder: Folder) {
        
        return delete(folder)
    }
    
	func postChildrenDidChangeNotification() {
		
		NotificationCenter.default.post(name: .ChildrenDidChange, object: self)
	}
}

