//
//  CloudKitStatsView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 3/20/26.
//

import SwiftUI
import Account

struct CloudKitStatsView: View {

	private static let model = CloudKitStatsViewModel()
	private let model = CloudKitStatsView.model

	var body: some View {
		List {
			statusSection
			statusRecordsSection
			contentRecordsSection
			if let fetchError = model.fetchStatus.fetchError {
				Section {
					Text(fetchError.localizedDescription)
						.foregroundStyle(.red)
				}
			}
		}
		.navigationTitle("iCloud Storage Stats")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				if model.fetchStatus.isFetching {
					Button("Cancel") {
						model.cancelFetch()
					}
				} else {
					Button("Copy") {
						UIPasteboard.general.string = model.statsText
					}
					.disabled(!model.fetchStatus.isCompleted)
				}
			}
		}
		.onAppear {
			if case .idle = model.fetchStatus {
				model.fetch()
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
			if model.fetchStatus.isFetching {
				model.cancelFetch()
			}
		}
	}

	@ViewBuilder private var statusSection: some View {
		Section {
			switch model.fetchStatus {
			case .idle:
				EmptyView()
			case .fetching:
				HStack(spacing: 6) {
					ProgressView()
						.controlSize(.small)
					Text("Scanning iCloud storage")
						.foregroundStyle(.secondary)
				}
			case .completed:
				HStack(spacing: 4) {
					Image(systemName: "checkmark.circle.fill")
						.foregroundStyle(.green)
					Text("Scan completed.")
						.foregroundStyle(.secondary)
					Spacer()
					Button("Refresh") {
						model.fetch()
					}
				}
			case .canceled:
				HStack(spacing: 4) {
					Text("Canceled.")
						.foregroundStyle(.secondary)
					Spacer()
					Button("Refresh") {
						model.fetch()
					}
				}
			case .error:
				HStack(spacing: 4) {
					Text("Scan failed.")
						.foregroundStyle(.secondary)
					Spacer()
					Button("Refresh") {
						model.fetch()
					}
				}
			}
		}
	}

	private var statusRecordsSection: some View {
		Section {
			statsRow("Status Records", model.stats.statusCount, isHeader: true)
			statsRow("Starred", model.stats.starredStatusCount)
			statsRow("Unread", model.stats.unreadStatusCount)
			statsRow("Read", model.stats.readStatusCount)
			statsRow("Stale", model.stats.staleStatusCount)
		}
	}

	private var contentRecordsSection: some View {
		Section {
			statsRow("Article Content Records", model.stats.articleCount, isHeader: true)
			statsRow("Starred", model.stats.starredArticleCount)
			statsRow("Unread", model.stats.unreadArticleCount)
			statsRow("Read", model.stats.readArticleCount)
			statsRow("Orphaned", model.stats.orphanedArticleCount)
		}
	}

	private func statsRow(_ label: String, _ count: Int, isHeader: Bool = false) -> some View {
		HStack {
			Text(label)
				.fontWeight(isHeader ? .semibold : .regular)
			Spacer()
			Text("\(count)")
				.monospacedDigit()
				.foregroundStyle(model.fetchStatus.isFetching ? .secondary : .primary)
		}
	}
}
