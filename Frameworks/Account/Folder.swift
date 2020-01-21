//
//  Folder.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import RSCore

public final class Folder: Feed, Renamable, Container, Hashable {

	public var defaultReadFilterType: ReadFilterType {
		return .read
	}
	
	public var containerID: ContainerIdentifier? {
		guard let accountID = account?.accountID else {
			assertionFailure("Expected feed.account, but got nil.")
			return nil
		}
		return ContainerIdentifier.folder(accountID, nameForDisplay)
	}
	
	public var feedID: FeedIdentifier? {
		guard let accountID = account?.accountID else {
			assertionFailure("Expected feed.account, but got nil.")
			return nil
		}
		return FeedIdentifier.folder(accountID, nameForDisplay)
	}

	public weak var account: Account?
	public var topLevelWebFeeds: Set<WebFeed> = Set<WebFeed>()
	public var folders: Set<Folder>? = nil // subfolders are not supported, so this is always nil
	
	public var name: String? {
		didSet {
			postDisplayNameDidChangeNotification()
		}
	}
	
	static let untitledName = NSLocalizedString("Untitled ƒ", comment: "Folder name")
	public let folderID: Int // not saved: per-run only
	public var externalID: String? = nil
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

	public func rename(to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let account = account else { return }
		account.renameFolder(self, to: name, completion: completion)
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

	public func flattenedWebFeeds() -> Set<WebFeed> {
		// Since sub-folders are not supported, it’s always the top-level feeds.
		return topLevelWebFeeds
	}

	public func objectIsChild(_ object: AnyObject) -> Bool {
		// Folders contain Feed objects only, at least for now.
		guard let feed = object as? WebFeed else {
			return false
		}
		return topLevelWebFeeds.contains(feed)
	}

	public func addWebFeed(_ feed: WebFeed) {
		topLevelWebFeeds.insert(feed)
		postChildrenDidChangeNotification()
	}
	
	public func addFeeds(_ feeds: Set<WebFeed>) {
		guard !feeds.isEmpty else {
			return
		}
		topLevelWebFeeds.formUnion(feeds)
		postChildrenDidChangeNotification()
	}
	
	public func removeWebFeed(_ feed: WebFeed) {
		topLevelWebFeeds.remove(feed)
		postChildrenDidChangeNotification()
	}
	
	public func removeFeeds(_ feeds: Set<WebFeed>) {
		guard !feeds.isEmpty else {
			return
		}
		topLevelWebFeeds.subtract(feeds)
		postChildrenDidChangeNotification()
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
		for feed in topLevelWebFeeds {
			updatedUnreadCount += feed.unreadCount
		}
		unreadCount = updatedUnreadCount
	}

	func childrenContain(_ feed: WebFeed) -> Bool {
		return topLevelWebFeeds.contains(feed)
	}
}

// MARK: - OPMLRepresentable

extension Folder: OPMLRepresentable {

	public func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String {
		
		let attrExternalID: String = {
			if allowCustomAttributes, let externalID = externalID {
				return " nnw_externalID=\"\(externalID.escapingSpecialXMLCharacters)\""
			} else {
				return ""
			}
		}()
		
		let escapedTitle = nameForDisplay.escapingSpecialXMLCharacters
		var s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\"\(attrExternalID)>\n"
		s = s.prepending(tabCount: indentLevel)

		var hasAtLeastOneChild = false

		for feed in topLevelWebFeeds.sorted()  {
			s += feed.OPMLString(indentLevel: indentLevel + 1, allowCustomAttributes: allowCustomAttributes)
			hasAtLeastOneChild = true
		}

		if !hasAtLeastOneChild {
			s = "<outline text=\"\(escapedTitle)\" title=\"\(escapedTitle)\"\(attrExternalID)/>\n"
			s = s.prepending(tabCount: indentLevel)
			return s
		}

		s = s + String(tabCount: indentLevel) + "</outline>\n"

		return s
	}
}

// MARK: Set

extension Set where Element == Folder {
	
	func sorted() -> Array<Folder> {
		return sorted(by: { (folder1, folder2) -> Bool in
			return folder1.nameForDisplay.localizedStandardCompare(folder2.nameForDisplay) == .orderedAscending
		})
	}
	
}
