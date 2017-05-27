//
//  FolderProtocol.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

public typealias FolderVisitBlock = (_ obj: AnyObject) -> Bool

public let FolderChildrenDidChangeNotification = "FolderChildNodesDidChangeNotification"

public func FolderPostChildrenDidChangeNotification(_ folder: Folder) {

	NotificationCenter.default.post(name: NSNotification.Name(rawValue: FolderChildrenDidChangeNotification), object: folder)
}

public protocol Folder: class, UnreadCountProvider, DisplayNameProvider {
	
	// TODO: get rid of children, flattenedFeeds, and some default implementations in favor of faster, specific ones.
	
//	var children: NSSet {get}
	var account: Account? {get}
	
	var hasAtLeastOneFeed: Bool {get} //Recursive
	var flattenedFeeds: NSSet {get}
	
	func objectIsChild(_ obj: AnyObject) -> Bool
	func objectIsDescendant(_ obj: AnyObject) -> Bool
	
	func fetchArticles() -> [Article]
	
	// visitBlock should return true to stop visiting.
	// visitObjects returns true if a visitBlock returned true.
	func visitObjects(_ recurse: Bool, visitBlock: FolderVisitBlock) -> Bool
	func visitChildren(visitBlock: FolderVisitBlock) -> Bool // Above with recurse = false
	
	func findObject(_ recurse: Bool, visitBlock: FolderVisitBlock) -> AnyObject?

	func canAddItem(_ item: AnyObject) -> Bool
	func addItem(_ item: AnyObject) -> Bool // Return true even if item already exists.
	func addItems(_ items: [AnyObject]) -> Bool // Return true even if some items already exist.

	func canAddFolderWithName(_ folderName: String) -> Bool // Special case: folder with name exists. Return true in that case.
	func ensureFolderWithName(_ folderName: String) -> Folder? // Return folder even if item already exists.
	
	// Recurses
	func existingFeedWithID(_ feedID: String) -> Feed?
	func existingFeedWithURL(_ urlString: String) -> Feed?
	
	// Does not recurse.
	func existingFolderWithName(_ name: String) -> Folder?

	// Doesn't add feed. Just creates instance.
	func createFeedWithName(_ name: String?, editedName: String?, urlString: String) -> Feed?

	func deleteItems(_ items: [AnyObject])
	
	// Exporting OPML.
	func opmlString(indentLevel: Int) -> String
}

public extension Folder {
	
	var hasAtLeastOneFeed: Bool {
		get {
			return visitObjects(true) { (oneObject) in
				
				return oneObject is Feed
			}
		}
	}

	func visitChildren(visitBlock: FolderVisitBlock) -> Bool {
		
		return visitObjects(false, visitBlock: visitBlock)
	}
	
	func findObject(_ recurse: Bool, visitBlock: FolderVisitBlock) -> AnyObject? {
		
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

	func addItems(_ items: [AnyObject]) -> Bool {

		var atLeastOneItemAdded = false
		items.forEach { (oneItem) in
			if addItem(oneItem) {
				atLeastOneItemAdded = true
			}
		}
		return atLeastOneItemAdded
	}
	
	func opmlString(indentLevel: Int) -> String {
		
		let escapedTitle = nameForDisplay.rs_stringByEscapingSpecialXMLCharacters()
		var s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\">\n"
		s = s.rs_string(byPrependingNumberOfTabs: indentLevel)
		
		var hasAtLeastOneChild = false
		
		let _ = visitChildren { (oneChild) -> Bool in
			
			hasAtLeastOneChild = true
			if let oneFolder = oneChild as? Folder {
				s = s + oneFolder.opmlString(indentLevel: indentLevel + 1)
			}
			else if let oneFeed = oneChild as? Feed {
				s = s + oneFeed.opmlString(indentLevel: indentLevel + 1)
			}
			
			return false
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

