//
//  AccountStatsViewModel.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/7/26.
//

import Foundation
import Account
import ArticlesDatabase

struct AccountStatsRowData {

	let accountID: String
	let name: String
	let typeName: String
	let isActive: Bool
	let feedCount: Int
	let folderCount: Int
	var totalArticleCount: Int?
	var statusesCount: Int?
	var unreadCount: Int?
	var starredCount: Int?
	let databaseSizeBytes: Int
}

@MainActor final class AccountStatsViewModel {

	var accountStats = [String: AccountStatsRowData]()
	private(set) var sortedAccountStats = [AccountStatsRowData]()
	var sortDescriptor: NSSortDescriptor?

	private var cachedTotalArticleCount = 0
	private var cachedTotalUnreadCount = 0
	private var cachedTotalStarredCount = 0
	private var cachedTotalStatusesCount = 0

	func refresh() async {
		let accounts = AccountManager.shared.sortedAccounts
		let previous = accountStats

		// Preserve previous async-loaded counts so cells keep their values until the new fetches return.
		var newStats = [String: AccountStatsRowData]()
		for account in accounts {
			let previousData = previous[account.accountID]
			newStats[account.accountID] = AccountStatsRowData(
				accountID: account.accountID,
				name: account.nameForDisplay,
				typeName: account.type.displayName,
				isActive: account.isActive,
				feedCount: account.flattenedFeeds().count,
				folderCount: account.folders?.count ?? 0,
				totalArticleCount: previousData?.totalArticleCount,
				statusesCount: previousData?.statusesCount,
				unreadCount: previousData?.unreadCount,
				starredCount: previousData?.starredCount,
				databaseSizeBytes: databaseSize(for: account)
			)
		}
		accountStats = newStats

		for account in accounts {
			guard let counts = try? await account.fetchArticleCountsAsync(), var stats = accountStats[account.accountID] else {
				continue
			}
			stats.totalArticleCount = counts.totalCount
			stats.unreadCount = counts.unreadCount
			stats.starredCount = counts.starredCount
			stats.statusesCount = counts.statusesCount
			accountStats[account.accountID] = stats
		}

		recomputeCachedTotals()
		applySort()
	}

	func applySort() {
		let unsorted = Array(accountStats.values)
		let ascending = sortDescriptor?.ascending ?? true
		let key = sortDescriptor?.key ?? "account"
		switch key {
		case "account":
			sortedAccountStats = unsorted.sorted { Self.compareStrings($0.name, $1.name, ascending: ascending) }
		case "dbSize":
			sortedAccountStats = unsorted.sorted { Self.compareInts($0.databaseSizeBytes, $1.databaseSizeBytes, ascending: ascending) }
		case "feeds":
			sortedAccountStats = unsorted.sorted { Self.compareInts($0.feedCount, $1.feedCount, ascending: ascending) }
		case "folders":
			sortedAccountStats = unsorted.sorted { Self.compareInts($0.folderCount, $1.folderCount, ascending: ascending) }
		case "articles":
			sortedAccountStats = unsorted.sorted { Self.compareOptionalInts($0.totalArticleCount, $1.totalArticleCount, ascending: ascending) }
		case "statuses":
			sortedAccountStats = unsorted.sorted { Self.compareOptionalInts($0.statusesCount, $1.statusesCount, ascending: ascending) }
		case "unread":
			sortedAccountStats = unsorted.sorted { Self.compareOptionalInts($0.unreadCount, $1.unreadCount, ascending: ascending) }
		case "starred":
			sortedAccountStats = unsorted.sorted { Self.compareOptionalInts($0.starredCount, $1.starredCount, ascending: ascending) }
		default:
			sortedAccountStats = unsorted
		}
	}

	var totalFeedCount: Int {
		accountStats.values.reduce(0) { $0 + $1.feedCount }
	}

	var totalFolderCount: Int {
		accountStats.values.reduce(0) { $0 + $1.folderCount }
	}

	var totalArticleCount: Int {
		cachedTotalArticleCount
	}

	var totalUnreadCount: Int {
		cachedTotalUnreadCount
	}

	var totalStarredCount: Int {
		cachedTotalStarredCount
	}

	var totalStatusesCount: Int {
		cachedTotalStatusesCount
	}

	var totalDatabaseSizeBytes: Int {
		accountStats.values.reduce(0) { $0 + $1.databaseSizeBytes }
	}
}

private extension AccountStatsViewModel {

	static func compareStrings(_ lhs: String, _ rhs: String, ascending: Bool) -> Bool {
		let result = lhs.localizedCaseInsensitiveCompare(rhs)
		return ascending ? result == .orderedAscending : result == .orderedDescending
	}

	static func compareInts(_ lhs: Int, _ rhs: Int, ascending: Bool) -> Bool {
		ascending ? lhs < rhs : lhs > rhs
	}

	static func compareOptionalInts(_ lhs: Int?, _ rhs: Int?, ascending: Bool) -> Bool {
		switch (lhs, rhs) {
		case (nil, nil):
			return false
		case (nil, _):
			return ascending
		case (_, nil):
			return !ascending
		case let (l?, r?):
			return ascending ? l < r : l > r
		}
	}

	func recomputeCachedTotals() {
		cachedTotalArticleCount = accountStats.values.reduce(0) { $0 + ($1.totalArticleCount ?? 0) }
		cachedTotalUnreadCount = accountStats.values.reduce(0) { $0 + ($1.unreadCount ?? 0) }
		cachedTotalStarredCount = accountStats.values.reduce(0) { $0 + ($1.starredCount ?? 0) }
		cachedTotalStatusesCount = accountStats.values.reduce(0) { $0 + ($1.statusesCount ?? 0) }
	}

	func databaseSize(for account: Account) -> Int {
		let dataFolder = account.dataFolder as NSString
		let databaseNames = ["DB.sqlite3", "FeedSettings.db", "Sync.sqlite3"]
		var totalSize = 0

		for databaseName in databaseNames {
			let path = dataFolder.appendingPathComponent(databaseName)
			if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
			   let size = attributes[FileAttributeKey.size] as? Int {
				totalSize += size
			}
		}

		return totalSize
	}
}
