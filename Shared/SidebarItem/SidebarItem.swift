//
//  SidebarItem.swift
//  Account
//
//  Created by Maurice Parker on 11/15/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Account
import Core

enum ReadFilterType {
	case read
	case none
	case alwaysRead
}

protocol SidebarItem: SidebarItemIdentifiable, ArticleFetcher, DisplayNameProvider, UnreadCountProvider {

	var account: Account? { get }
	var defaultReadFilterType: ReadFilterType { get }
}

extension SidebarItem {
	
	func readFiltered(readFilterEnabledTable: [SidebarItemIdentifier: Bool]) -> Bool {
		guard defaultReadFilterType != .alwaysRead else {
			return true
		}
		if let sidebarItemID, let readFilterEnabled = readFilterEnabledTable[sidebarItemID] {
			return readFilterEnabled
		} else {
			return defaultReadFilterType == .read
		}
	}
}

extension Feed: SidebarItem {

	var defaultReadFilterType: ReadFilterType {
		return .none
	}
}

extension Folder: SidebarItem {

	var defaultReadFilterType: ReadFilterType {
		return .read
	}
}

extension AccountManager {

	func existingSidebarItem(with sidebarItemID: SidebarItemIdentifier) -> SidebarItem? {
		switch sidebarItemID {
		case .folder(let accountID, let folderName):
			if let account = existingAccount(with: accountID) {
				return account.existingFolder(with: folderName)
			}
		case .feed(let accountID, let feedID):
			if let account = existingAccount(with: accountID) {
				return account.existingFeed(withFeedID: feedID)
			}
		default:
			break
		}
		return nil
	}
}
