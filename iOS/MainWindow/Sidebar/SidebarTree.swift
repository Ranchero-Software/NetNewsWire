//
//  SidebarTree.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 2/7/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import Account

typealias SectionID = Int
typealias ItemID = Int

protocol Section: Identifiable {}
protocol Item: Identifiable {}

@MainActor protocol SidebarContainer: Identifiable {

	var isExpanded: Bool { get set }
	var items: [any Item] { get }

	func updateItems()
}

extension SidebarContainer {

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
	var isExpanded = true

	let items: [any Item] = [
		SidebarSmartFeed(SmartFeedsController.shared.todayFeed),
		SidebarSmartFeed(SmartFeedsController.shared.unreadFeed),
		SidebarSmartFeed(SmartFeedsController.shared.starredFeed)
	]

	func updateItems() {
	}
}


// MARK: - SidebarSmartFeed

@MainActor final class SidebarSmartFeed: Item {

	let id = createID()
	let smartFeed: any PseudoFeed

	init(_ smartFeed: any PseudoFeed) {
		self.smartFeed = smartFeed
	}
}

// MARK: - SidebarAccount

@MainActor final class SidebarAccount: Section, SidebarContainer {

	let id = createID()
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
}

// MARK: - SidebarFolder

@MainActor final class SidebarFolder: Item, SidebarContainer {

	let id = createID()
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

	init(_ feed: Feed) {
		self.feedID = feed.feedID
		self.feed = feed
	}
}

// MARK: - SidebarTree

@MainActor final class SidebarTree {

	var sections = [any Section]()

	private lazy var sidebarSmartFeedsFolder = SidebarSmartFeedsFolder()

	func rebuildTree() {

		rebuildSections()

		for section in sections where section is SidebarAccount {
			let sidebarAccount = section as! SidebarAccount
			sidebarAccount.updateItems()
		}
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
