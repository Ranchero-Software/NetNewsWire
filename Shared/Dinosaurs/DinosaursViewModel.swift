//
//  DinosaursViewModel.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/1/26.
//

import Foundation
import os
import Account
import RSCore

enum DinosaurSortKey: String {

	case feedName
	case feedURL
	case accountName
	case lastArticleDate
	case lastResponseCode
}

struct DinosaurRow: Identifiable {

	let id: String
	let feed: Feed
	let account: Account
	let accountName: String
	let feedName: String
	let feedURL: String
	let lastArticleDate: Date?
	let lastResponseCode: Int?
}

@MainActor struct DinosaurDeletion {

	let feed: Feed
	let account: Account
	let containers: [Container]
}

@Observable
@MainActor final class DinosaursViewModel {

	private(set) var rows = [DinosaurRow]()
	private(set) var showAccountColumn = false
	var monthThreshold = 6
	private var sortDescriptor: NSSortDescriptor?

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DinosaursViewModel")

	func refresh() async {
		let start = Date()
		defer {
			let elapsed = Date().timeIntervalSince(start)
			Self.logger.info("DinosaursViewModel refresh: \(String(format: "%.3f", elapsed)) seconds, \(self.rows.count) rows")
		}
		let accounts = AccountManager.shared.activeAccounts
		let cutoffDate = Calendar.current.date(byAdding: .month, value: -monthThreshold, to: Date()) ?? .distantPast

		var newRows = [DinosaurRow]()
		for account in accounts {
			let latestDates = await account.fetchLastUpdateDates()
			for feed in account.flattenedFeeds() {
				let latestDate = latestDates[feed.feedID]
				guard let latestDate, latestDate < cutoffDate else {
					continue
				}
				newRows.append(DinosaurRow(
					id: feed.url + account.accountID,
					feed: feed,
					account: account,
					accountName: account.nameForDisplay,
					feedName: feed.nameForDisplay,
					feedURL: feed.url,
					lastArticleDate: latestDate,
					lastResponseCode: feed.lastResponseCode
				))
			}
		}

		rows = newRows
		showAccountColumn = accounts.count > 1
		applySort()
	}

	func clear() {
		rows = []
	}

	private func applySort() {
		let ascending = sortDescriptor?.ascending ?? true
		let key: DinosaurSortKey = {
			guard let rawKey = sortDescriptor?.key, let sortKey = DinosaurSortKey(rawValue: rawKey) else {
				return .feedName
			}
			return sortKey
		}()
		switch key {
		case .feedName:
			sortWithURLTiebreaker(ascending: ascending) { $0.feedName.localizedCaseInsensitiveCompare($1.feedName) }
		case .feedURL:
			rows.sort { compareStrings($0.feedURL, $1.feedURL, ascending: ascending) }
		case .accountName:
			sortWithURLTiebreaker(ascending: ascending) { $0.accountName.localizedCaseInsensitiveCompare($1.accountName) }
		case .lastArticleDate:
			sortWithURLTiebreaker(ascending: ascending) { compareOptionals($0.lastArticleDate, $1.lastArticleDate) }
		case .lastResponseCode:
			sortWithURLTiebreaker(ascending: ascending) { compareOptionals($0.lastResponseCode, $1.lastResponseCode) }
		}
	}

	func sortBy(_ key: DinosaurSortKey, ascending: Bool) {
		sortDescriptor = NSSortDescriptor(key: key.rawValue, ascending: ascending)
		applySort()
	}

	func deleteFeeds(at indexes: IndexSet) -> [DinosaurDeletion] {
		let feedsToDelete = indexes.compactMap { rows.indices.contains($0) ? rows[$0] : nil }
		let deletions = feedsToDelete.map { row in
			DinosaurDeletion(feed: row.feed, account: row.account, containers: row.account.existingContainers(withFeed: row.feed))
		}
		performDeletions(deletions)
		return deletions
	}

	func performDeletions(_ deletions: [DinosaurDeletion]) {
		for deletion in deletions {
			for container in deletion.containers {
				deletion.account.removeFeed(deletion.feed, from: container) { _ in }
			}
		}
	}

	func performRestorations(_ deletions: [DinosaurDeletion]) {
		for deletion in deletions {
			for container in deletion.containers {
				deletion.account.restoreFeed(deletion.feed, container: container) { _ in }
			}
		}
	}
}

private extension DinosaursViewModel {

	func sortWithURLTiebreaker(ascending: Bool, primary: (DinosaurRow, DinosaurRow) -> ComparisonResult) {
		rows.sort { lhs, rhs in
			let primaryResult = primary(lhs, rhs)
			let result: ComparisonResult = {
				if primaryResult == .orderedSame {
					return lhs.feedURL.localizedCaseInsensitiveCompare(rhs.feedURL)
				}
				return primaryResult
			}()
			return ascending ? result == .orderedAscending : result == .orderedDescending
		}
	}
}
