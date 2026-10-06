//
//  AccountStatsView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 6/9/26.
//

import SwiftUI
import UIKit
import RSCore
import Account

struct AccountStatsView: View {

	private static let helpURL = URL(string: "https://netnewswire.com/help/account-stats.html")!

	private let model = AccountStatsViewModel()

	@State private var rows = [AccountStatsRowData]()
	@State private var totals: AccountStatsTotals?
	@State private var isVacuuming = false
	@State private var showHelp = false

	var body: some View {
		List {
			ForEach(rows, id: \.accountID) { row in
				Section {
					ForEach(statItems(databaseSizeBytes: row.databaseSizeBytes, feedCount: row.feedCount, folderCount: row.folderCount, articleCount: row.articleCount, statusesCount: row.statusesCount, unreadCount: row.unreadCount, starredCount: row.starredCount)) { item in
						statsRow(item, isBold: false)
					}
					.foregroundStyle(row.isActive ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
				} header: {
					Text(headerTitle(for: row))
				}
			}

			if let totals, rows.count > 1 {
				Section {
					ForEach(statItems(databaseSizeBytes: totals.databaseSizeBytes, feedCount: totals.feedCount, folderCount: totals.folderCount, articleCount: totals.articleCount, statusesCount: totals.statusesCount, unreadCount: totals.unreadCount, starredCount: totals.starredCount)) { item in
						statsRow(item, isBold: true)
					}
				} header: {
					Text(NSLocalizedString("Totals", comment: "Totals section"))
				}
			}

			Section {
				Button(NSLocalizedString("Vacuum Databases", comment: "Vacuum databases button")) {
					vacuum()
				}
				.frame(maxWidth: .infinity)
				.disabled(isVacuuming)
			} footer: {
				VStack(spacing: 8) {
					Text(NSLocalizedString("Vacuuming may make databases faster.", comment: "Vacuum explanation"))
						.frame(maxWidth: .infinity, alignment: .center)
						.multilineTextAlignment(.center)
					ProgressView()
						.controlSize(.small)
						.opacity(isVacuuming ? 1 : 0)
				}
			}

			Section {
			} footer: {
				helpLinkFooter
			}
		}
		.navigationTitle(NSLocalizedString("Account Stats", comment: "Account Stats screen title"))
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					Task {
						await refresh()
					}
				} label: {
					Label(NSLocalizedString("Refresh", comment: "Refresh"), systemImage: "arrow.clockwise")
				}
				.disabled(isVacuuming)
			}
		}
		.sheet(isPresented: $showHelp) {
			SafariView(url: Self.helpURL)
		}
		.task {
			await refresh()
		}
		.onReceive(NotificationCenter.default.publisher(for: .UserDidAddAccount)) { _ in
			Task {
				await refresh()
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .UserDidDeleteAccount)) { _ in
			Task {
				await refresh()
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .AccountStateDidChange)) { _ in
			Task {
				await refresh()
			}
		}
	}
}

// MARK: - Private

private extension AccountStatsView {

	struct StatItem: Identifiable {

		let label: String
		let value: String

		var id: String { label }
	}

	var helpLinkFooter: some View {
		Button(NSLocalizedString("Account Stats Help", comment: "Help link")) {
			showHelp = true
		}
		.font(.subheadline)
		.frame(maxWidth: .infinity)
		.padding(.top, 8)
	}

	func statsRow(_ item: StatItem, isBold: Bool) -> some View {
		HStack {
			Text(item.label)
			Spacer()
			Text(item.value)
				.monospacedDigit()
		}
		.fontWeight(isBold ? .semibold : .regular)
	}

	func statItems(databaseSizeBytes: Int, feedCount: Int, folderCount: Int, articleCount: Int, statusesCount: Int, unreadCount: Int, starredCount: Int) -> [StatItem] {
		[
			StatItem(label: NSLocalizedString("Databases", comment: "Database size row label"), value: Self.formattedSize(databaseSizeBytes)),
			StatItem(label: NSLocalizedString("Feeds", comment: "Feeds"), value: Self.formattedNumber(feedCount)),
			StatItem(label: NSLocalizedString("Folders", comment: "Folders"), value: Self.formattedNumber(folderCount)),
			StatItem(label: NSLocalizedString("Articles", comment: "Articles"), value: Self.formattedNumber(articleCount)),
			StatItem(label: NSLocalizedString("Statuses", comment: "Statuses"), value: Self.formattedNumber(statusesCount)),
			StatItem(label: NSLocalizedString("Unread", comment: "Unread"), value: Self.formattedNumber(unreadCount)),
			StatItem(label: NSLocalizedString("Starred", comment: "Starred"), value: Self.formattedNumber(starredCount))
		]
	}

	func headerTitle(for row: AccountStatsRowData) -> String {
		if row.name == row.typeName {
			return row.name
		}
		return "\(row.name) (\(row.typeName))"
	}

	func refresh() async {
		await model.refresh()
		rows = model.sortedAccountStats
		totals = model.totals
	}

	func vacuum() {
		guard !isVacuuming else {
			return
		}
		isVacuuming = true
		Task {
			await (UIApplication.shared.delegate as? AppDelegate)?.vacuumAllDatabases()
			isVacuuming = false
			await refresh()
		}
	}

	static func formattedNumber(_ value: Int) -> String {
		value.formatted(.number)
	}

	static func formattedSize(_ bytes: Int) -> String {
		Int64(bytes).formatted(.byteCount(style: .file))
	}
}
