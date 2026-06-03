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
	let articleCount: Int
	let statusesCount: Int
	let unreadCount: Int
	let starredCount: Int
	let databaseSizeBytes: Int
}

struct AccountStatsTotals {

	let feedCount: Int
	let folderCount: Int
	let articleCount: Int
	let statusesCount: Int
	let unreadCount: Int
	let starredCount: Int
	let databaseSizeBytes: Int

	init(rows: [AccountStatsRowData]) {
		feedCount = rows.reduce(0) { $0 + $1.feedCount }
		folderCount = rows.reduce(0) { $0 + $1.folderCount }
		articleCount = rows.reduce(0) { $0 + $1.articleCount }
		statusesCount = rows.reduce(0) { $0 + $1.statusesCount }
		unreadCount = rows.reduce(0) { $0 + $1.unreadCount }
		starredCount = rows.reduce(0) { $0 + $1.starredCount }
		databaseSizeBytes = rows.reduce(0) { $0 + $1.databaseSizeBytes }
	}
}

@MainActor final class AccountStatsViewModel {

	private(set) var sortedAccountStats = [AccountStatsRowData]()
	private(set) var totals = AccountStatsTotals(rows: [])
	var sortDescriptor: NSSortDescriptor?

	func refresh() async {
		var rows = [AccountStatsRowData]()
		for account in AccountManager.shared.sortedAccounts {
			let counts = try? await account.fetchArticleCountsAsync()
			rows.append(AccountStatsRowData(
				accountID: account.accountID,
				name: account.nameForDisplay,
				typeName: account.type.displayName,
				isActive: account.isActive,
				feedCount: account.flattenedFeeds().count,
				folderCount: account.folders?.count ?? 0,
				articleCount: counts?.totalCount ?? 0,
				statusesCount: counts?.statusesCount ?? 0,
				unreadCount: counts?.unreadCount ?? 0,
				starredCount: counts?.starredCount ?? 0,
				databaseSizeBytes: databaseSize(for: account)
			))
		}
		totals = AccountStatsTotals(rows: rows)
		sortedAccountStats = rows
		applySort()
	}

	func applySort() {
		let ascending = sortDescriptor?.ascending ?? true
		switch sortDescriptor?.key ?? "name" {
		case "name":
			sortedAccountStats.sort { Self.compareStrings($0.name, $1.name, ascending: ascending) }
		case "databaseSizeBytes":
			sortedAccountStats.sort { Self.compareInts($0.databaseSizeBytes, $1.databaseSizeBytes, ascending: ascending) }
		case "feedCount":
			sortedAccountStats.sort { Self.compareInts($0.feedCount, $1.feedCount, ascending: ascending) }
		case "folderCount":
			sortedAccountStats.sort { Self.compareInts($0.folderCount, $1.folderCount, ascending: ascending) }
		case "articleCount":
			sortedAccountStats.sort { Self.compareInts($0.articleCount, $1.articleCount, ascending: ascending) }
		case "statusesCount":
			sortedAccountStats.sort { Self.compareInts($0.statusesCount, $1.statusesCount, ascending: ascending) }
		case "unreadCount":
			sortedAccountStats.sort { Self.compareInts($0.unreadCount, $1.unreadCount, ascending: ascending) }
		case "starredCount":
			sortedAccountStats.sort { Self.compareInts($0.starredCount, $1.starredCount, ascending: ascending) }
		default:
			break
		}
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
