//
//  Container.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Data

public typealias VisitBlock = (_ obj: AnyObject) -> Bool // Return true to stop

extension NSNotification.Name {
	
	public static let ChildrenDidChange = Notification.Name("ChildrenDidChangeNotification")
}

public protocol Container {

	//Recursive
	func hasAtLeastOneFeed() -> Bool
	func flattenedFeeds() -> Set<Feed>
	func existingFeed(with feedID: String) -> Feed?
	func existingFeed(withURL url: String) -> Feed?
	func hasFeed(withURL url: String) -> Bool
	
	func isChild(_ obj: AnyObject) -> Bool

	// visitBlock should return true to stop visiting.
	// visitObjects returns true if a visitBlock returned true.
	func visitObjects(_ recurse: Bool, _ visitBlock: VisitBlock) -> Bool
}

public extension Container {
	
	func hasAtLeastOneFeed() -> Bool {
		
		let foundObject = findObject(true, visitBlock: { (oneDescendant) -> Bool in
			return oneDescendant is Feed
		})
		return foundObject != nil
	}
	
	func existingFeed(with feedID: String) -> Feed? {
		
		let foundObject = findObject(true) { (oneDescendant) -> Bool in
			if let oneFeed = oneDescendant as? Feed, oneFeed.feedID == feedID {
				return true
			}
			return false
		}
		return foundObject as! Feed?
	}

	func existingFeed(withURL url: String) -> Feed? {
		
		let foundObject = findObject(true) { (oneDescendant) -> Bool in
			if let oneFeed = oneDescendant as? Feed, oneFeed.url == url {
				return true
			}
			return false
		}
		return foundObject as! Feed?
	}
	
	func hasFeed(withURL url: String) -> Bool {
	
		if let _ = existingFeed(withURL: url) {
			return true
		}
		return false
	}
	
	func visitChildren(visitBlock: VisitBlock) -> Bool {
		
		return visitObjects(false, visitBlock)
	}
	
	func findObject(_ recurse: Bool, visitBlock: @escaping VisitBlock) -> AnyObject? {
		
		var foundObject: AnyObject?
		
		let _ = visitObjects(recurse) { (oneObject) in
			
			if let _ = foundObject {
				return true
			}
			
			if visitBlock(oneObject) {
				foundObject = oneObject
				return true
			}
			
			return false
		}
			
		return foundObject
	}

	func objectIsChild(_ obj: AnyObject) -> Bool {
		
		return visitObjects(false) { (oneObject) in
			return obj === oneObject
		}
	}
	
	func objectIsDescendant(_ obj: AnyObject) -> Bool {
		
		return visitObjects(true) { (oneObject) in
			return obj === oneObject
		}
	}
	
	func existingFolderWithName(_ name: String) -> Folder? {

		let foundObject = findObject(false) { (oneObject) in
			if let oneFolder = oneObject as? Folder, oneFolder.nameForDisplay == name {
				return true
			}
			return false
		}
		return foundObject as! Folder?
	}

	public func postChildrenDidChangeNotification() {
		
		NotificationCenter.default.post(name: .ChildrenDidChange, object: self)
	}
}

