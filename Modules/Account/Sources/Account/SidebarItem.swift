//
//  SidebarItem.swift
//  Account
//
//  Created by Maurice Parker on 11/15/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

nonisolated public enum ReadFilterType: Sendable {
	case read
	case none
	case alwaysRead
}

@MainActor public protocol SidebarItem: SidebarItemIdentifiable, ArticleFetcher, DisplayNameProvider, UnreadCountProvider {
	@MainActor var account: Account? { get }
	@MainActor var defaultReadFilterType: ReadFilterType { get }
}

@MainActor public extension SidebarItem {

	func readFiltered(readFilterEnabledTable: [SidebarItemIdentifier: Bool], globalHideReadArticles: Bool = false) -> Bool {
		guard defaultReadFilterType != .alwaysRead else {
			return true
		}
		if let sidebarItemID, let readFilterEnabled = readFilterEnabledTable[sidebarItemID] {
			return readFilterEnabled
		} else {
			return globalHideReadArticles || defaultReadFilterType == .read
		}

	}
}
