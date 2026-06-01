//
//  DinosaursFeedProvider.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/31/26.
//

import Foundation
import Account

@MainActor struct DinosaursFeedProvider {

	let rows: [DinosaurRow]
	let showAccountColumn: Bool

	static func fetch(monthThreshold: Int) async -> DinosaursFeedProvider {
		let directReadingAccounts = AccountManager.shared.activeAccounts.filter {
			$0.type == .onMyMac || $0.type == .cloudKit
		}

		let showAccountColumn = directReadingAccounts.count > 1
		let cutoffDate = Calendar.current.date(byAdding: .month, value: -monthThreshold, to: Date())

		var rows = [DinosaurRow]()

		for account in directReadingAccounts {
			let latestDates: [String: Date]
			do {
				latestDates = try await account.fetchLastUpdateDates()
			} catch {
				continue
			}

			for feed in account.flattenedFeeds() {
				let latestDate = latestDates[feed.feedID]

				let isDinosaur: Bool
				if let latestDate, let cutoffDate {
					isDinosaur = latestDate < cutoffDate
				} else if latestDate == nil {
					isDinosaur = true
				} else {
					isDinosaur = false
				}

				if isDinosaur {
					let row = DinosaurRow(
						id: feed.url + account.accountID,
						feed: feed,
						account: account,
						accountName: account.nameForDisplay,
						feedName: feed.nameForDisplay,
						feedURL: feed.url,
						lastArticleDate: latestDate,
						lastResponseCode: feed.lastResponseCode
					)
					rows.append(row)
				}
			}
		}

		return DinosaursFeedProvider(rows: rows, showAccountColumn: showAccountColumn)
	}
}
