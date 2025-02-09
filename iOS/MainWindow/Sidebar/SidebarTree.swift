//
//  SidebarTree.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 2/7/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit
import Account

typealias SectionID = Int
typealias ItemID = Int

// MARK: - Protocols

/// A top-level collapsible item.
///
/// The Smart Feeds group and active `Account`s are `Section`s.
@MainActor protocol Section: SidebarContainer, Identifiable where ID == SectionID {
	var title: String { get }

	/// All `Item`s in the `Section`, even if contained by a `SidebarFolder`
	/// in that section.
	func flattenedItems() -> [any Item]
}

/// `Item`s are contained by `Sections`. They never appear at the top level.
/// They are hidden when a `Section` is collapsed.
///
/// Items are smart feeds, folders, and feeds.
@MainActor protocol Item: Identifiable where ID == ItemID {
	var title: String { get }
	var image: UIImage? { get }
}

/// A `SidebarContainer` contains `Item`s and is collapsible.
///
/// All `Section`s are `SidebarContainer`s.
///
/// `SidebarFolder` is also a `SidebarContainer`,
/// though it’s not a `Section`, because it contains `Item`s and is collapsible.
@MainActor protocol SidebarContainer: Identifiable where ID == SectionID {
	var isExpanded: Bool { get set }
	var items: [any Item] { get }

	func updateItems()
}

extension SidebarContainer {

	// These dictionaries make it fast to look up, given a Feed or Folder,
	// the existing SidebarFeed and SidebarFolder.
	// This way we can preserve identity across rebuilds of the tree.
	// (Meaning: after rebuilding the tree, a given Feed in a given Account
	// or Folder should have the same SidebarFeed object with the same id.
	// Same with Folders and SidebarFolder.)

	func createFeedsDictionary() -> [String: SidebarFeed] {
		var d = [String: SidebarFeed]() // feedID: SidebarFeed
		for item in items where item is SidebarFeed {
			let sidebarFeed = item as! SidebarFeed
			d[sidebarFeed.feedID] = sidebarFeed
		}
		return d
	}

	func createFoldersDictionary() -> [Int: SidebarFolder] {
		var d = [Int: SidebarFolder]()
		for item in items where item is SidebarFolder {
			let sidebarFolder = item as! SidebarFolder
			d[sidebarFolder.folderID] = sidebarFolder
		}
		return d
	}
}

// MARK: - SidebarSmartFeedsFolder

@MainActor final class SidebarSmartFeedsFolder: Section, SidebarContainer {

	let id = createID()

	var title: String {
		SmartFeedsController.shared.nameForDisplay
	}

	var isExpanded = true
	
	let items: [any Item] = [
		SidebarSmartFeed(SmartFeedsController.shared.todayFeed),
		SidebarSmartFeed(SmartFeedsController.shared.unreadFeed),
		SidebarSmartFeed(SmartFeedsController.shared.starredFeed)
	]

	func updateItems() {
	}

	func flattenedItems() -> [any Item] {
		items
	}
}

// MARK: - SidebarSmartFeed

@MainActor final class SidebarSmartFeed: Item {

	let id = createID()
	let smartFeed: any PseudoFeed

	var title: String {
		smartFeed.nameForDisplay
	}
	
	var image: UIImage? {
		smartFeed.smallIcon?.image
	}

	init(_ smartFeed: any PseudoFeed) {
		self.smartFeed = smartFeed
	}
}

// MARK: - SidebarAccount

@MainActor final class SidebarAccount: Section, SidebarContainer {

	let id = createID()
	var title: String {
		account?.nameForDisplay ?? "Untitled Account"
	}

	let accountID: String
	weak var account: Account?
	var isExpanded = true

	var items = [any Item]() { // top-level feeds and folders
		didSet {
			feedsDictionary = createFeedsDictionary()
			foldersDictionary = createFoldersDictionary()
		}
	}

	private var feedsDictionary = [String: SidebarFeed]()
	private var foldersDictionary = [Int: SidebarFolder]()

	init(_ account: Account) {
		self.accountID = account.accountID
		self.account = account
		updateItems()
	}

	func updateItems() {

		guard let account else {
			items = [any Item]()
			return
		}

		var sidebarFeeds = [SidebarFeed]()
		for feed in account.topLevelFeeds {
			if let existingFeed = feedsDictionary[feed.feedID] {
				sidebarFeeds.append(existingFeed)
			} else {
				sidebarFeeds.append(SidebarFeed(feed))
			}
		}

		var sidebarFolders = [SidebarFolder]()
		if let folders = account.folders {
			for folder in folders {
				if let existingFolder = foldersDictionary[folder.folderID] {
					sidebarFolders.append(existingFolder)
				} else {
					sidebarFolders.append(SidebarFolder(folder))
				}
			}
		}

		for folder in sidebarFolders {
			folder.updateItems()
		}

		// TODO: sort feeds
		items = sidebarFeeds + sidebarFolders
	}

	func flattenedItems() -> [any Item] {

		var temp = items

		for item in items {
			temp.append(item)
			if let container = item as? any SidebarContainer {
				temp.append(contentsOf: container.items)
			}
		}

		return temp
	}
}

// MARK: - SidebarFolder

@MainActor final class SidebarFolder: Item, SidebarContainer {

	let id = createID()

	var title: String {
		folder?.nameForDisplay ?? Folder.untitledName
	}

	var image: UIImage? {
		AppImage.folder
	}

	let folderID: Int
	weak var folder: Folder?
	var isExpanded = false
	var items = [any Item]() { // SidebarFeed
		didSet {
			feedsDictionary = createFeedsDictionary()
		}
	}

	private var feedsDictionary = [String: SidebarFeed]()

	init(_ folder: Folder) {
		self.folderID = folder.folderID
		self.folder = folder
		updateItems()
	}

	func updateItems() {

		guard let folder else {
			items = [any Item]()
			return
		}

		var sidebarFeeds = [any Item]()
		for feed in folder.topLevelFeeds {
			if let existingFeed = feedsDictionary[feed.feedID] {
				sidebarFeeds.append(existingFeed)
			} else {
				sidebarFeeds.append(SidebarFeed(feed))
			}
		}

		// TODO: sort feeds
		items = sidebarFeeds
	}
}

// MARK: - SidebarFeed

@MainActor final class SidebarFeed: Item {

	let id = createID()
	let feedID: String
	weak var feed: Feed?

	var title: String {
		feed?.nameForDisplay ?? Feed.untitledName
	}

	var image: UIImage? {
		if let feed {
			return IconImageCache.shared.imageForFeed(feed)?.image
		} else {
			return nil
		}
	}

	init(_ feed: Feed) {
		self.feedID = feed.feedID
		self.feed = feed
	}
}

// MARK: - SidebarTree

@MainActor final class SidebarTree {

	var sections = [any Section]()
	private var idsToItems = [ItemID: any Item]()
	private var idsToSections = [SectionID: any Section]()

	private lazy var sidebarSmartFeedsFolder = SidebarSmartFeedsFolder()

	func section(with id: SectionID) -> (any Section)? {
		idsToSections[id]
	}

	func item(with id: ItemID) -> (any Item)? {
		idsToItems[id]
	}

	func rebuild() {

		// In my testing, with two accounts and hundreds of feeds,
		// this function takes 2-3 milliseconds.

		rebuildSections()
		updateAllItems()
		rebuildIDsToItems()
		rebuildIDsToSections()
	}
}

private extension SidebarTree {

	func rebuildSections() {

		var updatedSections = [any Section]()
		updatedSections.append(sidebarSmartFeedsFolder)

		for account in AccountManager.shared.activeAccounts {
			if let existingSection = existingSection(for: account) {
				updatedSections.append(existingSection)
			} else {
				updatedSections.append(SidebarAccount(account))
			}
		}

		// TODO: sort accounts

		sections = updatedSections
	}

	func updateAllItems() {

		for section in sections where section is SidebarAccount {
			let sidebarAccount = section as! SidebarAccount
			sidebarAccount.updateItems()
		}
	}

	func rebuildIDsToItems() {

		var d = [ItemID: any Item]()

		for section in sections {
			for item in section.flattenedItems() {
				d[item.id] = item
			}
		}

		idsToItems = d
	}

	func rebuildIDsToSections() {

		var d = [SectionID: any Section]()

		for section in sections {
			d[section.id] = section
		}

		idsToSections = d
	}

	func existingSection(for account: Account) -> (any Section)? {

		// Linear search through array because it’s just a few items.

		let accountID = account.accountID

		for sidebarSection in sections where sidebarSection is SidebarAccount {
			let sidebarAccount = sidebarSection as! SidebarAccount
			if sidebarAccount.accountID == accountID {
				return sidebarAccount
			}
		}

		return nil
	}
}

// MARK: - IDs

@MainActor private var autoIncrementingID = 0

@MainActor private func createID() -> Int {
	defer { autoIncrementingID += 1 }
	return autoIncrementingID
}
