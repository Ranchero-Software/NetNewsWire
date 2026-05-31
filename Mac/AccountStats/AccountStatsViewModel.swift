//
//  AccountStatsViewModel.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/7/26.
//

import Foundation
import Account

extension Notification.Name {
	static let AccountStatsDidChange = Notification.Name("AccountStatsDidChange")
}

struct AccountStatsData {

	let accountID: String
	let name: String
	let typeName: String
	let isActive: Bool
	let feedCount: Int
	let folderCount: Int
	let totalArticleCount: Int
	let unreadCount: Int
	let starredCount: Int
	let databaseSizeBytes: Int
}

@MainActor final class AccountStatsViewModel {

	var accountStats = [AccountStatsData]()
	var isVacuuming = false

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleUserDidAddAccount(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUserDidDeleteAccount(_:)), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
	}

	@objc func handleUserDidAddAccount(_ notification: Notification) {
		refresh()
	}

	@objc func handleUserDidDeleteAccount(_ notification: Notification) {
		refresh()
	}

	@objc func handleAccountStateDidChange(_ notification: Notification) {
		refresh()
	}

	func refresh() {
		let accounts = AccountManager.shared.sortedAccounts
		accountStats = accounts.map { accountStatsData(for: $0) }
		NotificationCenter.default.post(name: .AccountStatsDidChange, object: self)
	}

	func vacuum() {
		isVacuuming = true
		NotificationCenter.default.post(name: .AccountStatsDidChange, object: self)

		Task {
			await AccountManager.shared.vacuumAllDatabases()
			isVacuuming = false
			refresh()
		}
	}

	var totalFeedCount: Int {
		accountStats.reduce(0) { $0 + $1.feedCount }
	}

	var totalFolderCount: Int {
		accountStats.reduce(0) { $0 + $1.folderCount }
	}

	var totalArticleCount: Int {
		accountStats.reduce(0) { $0 + $1.totalArticleCount }
	}

	var totalUnreadCount: Int {
		accountStats.reduce(0) { $0 + $1.unreadCount }
	}

	var totalStarredCount: Int {
		accountStats.reduce(0) { $0 + $1.starredCount }
	}

	var totalDatabaseSizeBytes: Int {
		accountStats.reduce(0) { $0 + $1.databaseSizeBytes }
	}
}

private extension AccountStatsViewModel {

	func accountStatsData(for account: Account) -> AccountStatsData {
		let feedCount = account.flattenedFeeds().count
		let folderCount = account.folders?.count ?? 0
		let unreadCount = account.unreadCount
		let starredCount = (try? account.fetchCountForStarredArticles()) ?? 0
		let totalArticleCount = (try? account.fetchAllArticlesCount()) ?? 0
		let databaseSizeBytes = databaseSize(for: account)

		return AccountStatsData(
			accountID: account.accountID,
			name: account.nameForDisplay,
			typeName: account.type.displayName,
			isActive: account.isActive,
			feedCount: feedCount,
			folderCount: folderCount,
			totalArticleCount: totalArticleCount,
			unreadCount: unreadCount,
			starredCount: starredCount,
			databaseSizeBytes: databaseSizeBytes
		)
	}

	func databaseSize(for account: Account) -> Int {
		let dataFolder = account.dataFolder as NSString
		let baseNames = ["DB.sqlite3", "FeedSettings.db", "Sync.sqlite3"]
		// WAL databases create multiple files.
		let suffixes = ["", "-wal", "-shm", "-journal"]
		var totalSize = 0

		for baseName in baseNames {
			for suffix in suffixes {
				let path = dataFolder.appendingPathComponent(baseName + suffix)
				if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
				   let size = attributes[FileAttributeKey.size] as? Int {
					totalSize += size
				}
			}
		}

		return totalSize
	}
}
