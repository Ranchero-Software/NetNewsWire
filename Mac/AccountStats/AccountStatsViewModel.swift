//
//  AccountStatsViewModel.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/7/26.
//

import Foundation
import Account
import ArticlesDatabase

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
	var totalArticleCount: Int?
	var statusesCount: Int?
	var unreadCount: Int?
	var starredCount: Int?
	let databaseSizeBytes: Int
}

@MainActor final class AccountStatsViewModel {

	var accountStats = [AccountStatsData]()
	var isVacuuming = false

	private var refreshGeneration = 0
	private var pendingAccountIDs = Set<String>()

	// Async-derived totals stay stable through a refresh — they only update once every account has reported.
	private var cachedTotalArticleCount = 0
	private var cachedTotalUnreadCount = 0
	private var cachedTotalStarredCount = 0
	private var cachedTotalStatusesCount = 0

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
		refreshGeneration += 1
		let generation = refreshGeneration

		let accounts = AccountManager.shared.sortedAccounts
		let previousByID = Dictionary(uniqueKeysWithValues: accountStats.map { ($0.accountID, $0) })

		// Preserve previous async-loaded counts while the new fetches are in flight — cells stay
		// at their old values instead of flickering to "—".
		accountStats = accounts.map { account in
			let previous = previousByID[account.accountID]
			return AccountStatsData(
				accountID: account.accountID,
				name: account.nameForDisplay,
				typeName: account.type.displayName,
				isActive: account.isActive,
				feedCount: account.flattenedFeeds().count,
				folderCount: account.folders?.count ?? 0,
				totalArticleCount: previous?.totalArticleCount,
				statusesCount: previous?.statusesCount,
				unreadCount: previous?.unreadCount,
				starredCount: previous?.starredCount,
				databaseSizeBytes: databaseSize(for: account)
			)
		}

		pendingAccountIDs = Set(accounts.map { $0.accountID })
		NotificationCenter.default.post(name: .AccountStatsDidChange, object: self)

		for account in accounts {
			loadCounts(for: account, generation: generation)
		}
	}

	func vacuum() {
		isVacuuming = true
		NotificationCenter.default.post(name: .AccountStatsDidChange, object: self)

		Task {
			await appDelegate.vacuumAllDatabases()
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
		accountStats.reduce(0) { $0 + $1.databaseSizeBytes }
	}
}

private extension AccountStatsViewModel {

	func loadCounts(for account: Account, generation: Int) {
		let accountID = account.accountID
		Task { @MainActor in
			let counts = try? await account.fetchArticleCountsAsync()
			guard generation == refreshGeneration else {
				return
			}
			guard let counts else {
				// Fetch failed (database suspended, etc.) — leave previous values in place.
				pendingAccountIDs.remove(accountID)
				if pendingAccountIDs.isEmpty {
					recomputeCachedTotals()
					NotificationCenter.default.post(name: .AccountStatsDidChange, object: self)
				}
				return
			}
			guard let index = accountStats.firstIndex(where: { $0.accountID == accountID }) else {
				return
			}
			accountStats[index].totalArticleCount = counts.totalCount
			accountStats[index].unreadCount = counts.unreadCount
			accountStats[index].starredCount = counts.starredCount
			accountStats[index].statusesCount = counts.statusesCount

			pendingAccountIDs.remove(accountID)
			if pendingAccountIDs.isEmpty {
				recomputeCachedTotals()
			}
			NotificationCenter.default.post(name: .AccountStatsDidChange, object: self)
		}
	}

	func recomputeCachedTotals() {
		cachedTotalArticleCount = accountStats.reduce(0) { $0 + ($1.totalArticleCount ?? 0) }
		cachedTotalUnreadCount = accountStats.reduce(0) { $0 + ($1.unreadCount ?? 0) }
		cachedTotalStarredCount = accountStats.reduce(0) { $0 + ($1.starredCount ?? 0) }
		cachedTotalStatusesCount = accountStats.reduce(0) { $0 + ($1.statusesCount ?? 0) }
	}

	func databaseSize(for account: Account) -> Int {
		let dataFolder = account.dataFolder as NSString
		let baseNames = ["DB.sqlite3", "FeedSettings.db", "Sync.sqlite3"]
		var totalSize = 0

		for baseName in baseNames {
			let path = dataFolder.appendingPathComponent(baseName)
			if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
			   let size = attributes[FileAttributeKey.size] as? Int {
				totalSize += size
			}
		}

		return totalSize
	}
}
