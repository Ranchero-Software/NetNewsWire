//
//  DinosaursView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/31/26.
//

@preconcurrency import AppKit
import SwiftUI
import Account

struct DinosaursView: View {

	@State private var monthThreshold = 3
	@State private var monthThresholdText = "3"
	@State private var rows = [DinosaurRow]()
	@State private var showAccountColumn = false
	@State private var selection = Set<String>()
	@State private var sortOrder = [KeyPathComparator(\DinosaurRow.feedName)]
	@State private var showDeleteConfirmation = false

	private static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter
	}()

	var body: some View {
		VStack(spacing: 0) {
			filterBar
			Divider()
			table
			Divider()
			buttonBar
		}
		.task {
			await fetchRows()
		}
	}

	private var filterBar: some View {
		HStack {
			Text("Show feeds that haven’t updated in", comment: "Dinosaurs filter prefix")
			TextField("", text: $monthThresholdText)
				.frame(width: 36)
				.multilineTextAlignment(.center)
				.onSubmit {
					if let value = Int(monthThresholdText), value > 0 {
						monthThreshold = value
						Task {
							await fetchRows()
						}
					} else {
						monthThresholdText = "\(monthThreshold)"
					}
				}
			Text("months", comment: "Dinosaurs filter unit")
			Spacer()
		}
		.padding(12)
	}

	private var table: some View {
		Table(rows, selection: $selection, sortOrder: $sortOrder) {
			TableColumn(Text("Name", comment: "Dinosaurs table column"), value: \.feedName)
				.width(min: 100, ideal: 200)
			TableColumn(Text("URL", comment: "Dinosaurs table column"), value: \.feedURL)
				.width(min: 100, ideal: 200)
			if showAccountColumn {
				TableColumn(Text("Account", comment: "Dinosaurs table column"), value: \.accountName)
					.width(min: 80, ideal: 120)
			}
			TableColumn(Text("Last Article", comment: "Dinosaurs table column"), value: \.lastArticleDate, comparator: OptionalDateComparator()) { row in
				Text(row.lastArticleDate.map { Self.dateFormatter.string(from: $0) } ?? "—")
			}
			.width(min: 80, ideal: 120)
			TableColumn(Text("Last Response", comment: "Dinosaurs table column"), value: \.lastResponseCode, comparator: OptionalIntComparator()) { row in
				Text(row.lastResponseCode.map { "\($0)" } ?? "—")
			}
			.width(min: 60, ideal: 80)
		}
		.onChange(of: sortOrder) {
			rows.sort(using: sortOrder)
		}
	}

	private var buttonBar: some View {
		HStack {
			Button(NSLocalizedString("Select in Sidebar", comment: "Dinosaurs button")) {
				selectInSidebar()
			}
			.disabled(selection.count != 1)

			Button(NSLocalizedString("Delete…", comment: "Dinosaurs button")) {
				showDeleteConfirmation = true
			}
			.disabled(selection.isEmpty)

			Button(NSLocalizedString("Go to Home Page", comment: "Dinosaurs button")) {
				goToHomePage()
			}
			.disabled(selection.isEmpty)

			Spacer()
		}
		.padding(12)
		.alert(NSLocalizedString("Delete Feeds", comment: "Dinosaurs delete confirmation title"), isPresented: $showDeleteConfirmation) {
			Button(NSLocalizedString("Cancel", comment: "Dinosaurs delete confirmation button"), role: .cancel) {}
			Button(NSLocalizedString("Delete", comment: "Dinosaurs delete confirmation button"), role: .destructive) {
				deleteSelectedFeeds()
			}
		} message: {
			if selection.count == 1 {
				if let row = selectedRows.first {
					Text("Are you sure you want to delete the feed \(row.feedName)?", comment: "Dinosaurs delete confirmation message — single feed")
				}
			} else {
				Text("Are you sure you want to delete \(selection.count) feeds?", comment: "Dinosaurs delete confirmation message — multiple feeds")
			}
		}
	}

	private var selectedRows: [DinosaurRow] {
		rows.filter { selection.contains($0.id) }
	}

	private func fetchRows() async {
		let provider = await DinosaursFeedProvider.fetch(monthThreshold: monthThreshold)
		rows = provider.rows.sorted(using: sortOrder)
		showAccountColumn = provider.showAccountColumn
		selection.removeAll()
	}

	private func selectInSidebar() {
		guard let row = selectedRows.first else {
			return
		}
		guard let mainWindowController = NSApp.mainWindow?.windowController as? MainWindowController else {
			return
		}
		mainWindowController.selectFeedInSidebar(row.feed)
	}

	private func deleteSelectedFeeds() {
		for row in selectedRows {
			let containers = row.account.existingContainers(withFeed: row.feed)
			for container in containers {
				row.account.removeFeed(row.feed, from: container) { _ in }
			}
		}
		Task {
			await fetchRows()
		}
	}

	private func goToHomePage() {
		for row in selectedRows {
			if let homePageURL = row.feed.homePageURL, let url = URL(string: homePageURL) {
				NSWorkspace.shared.open(url)
			}
		}
	}
}

struct OptionalDateComparator: SortComparator {
	var order: SortOrder = .forward

	func compare(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
		switch (lhs, rhs) {
		case (nil, nil):
			return .orderedSame
		case (nil, _):
			return order == .forward ? .orderedAscending : .orderedDescending
		case (_, nil):
			return order == .forward ? .orderedDescending : .orderedAscending
		case let (l?, r?):
			let result = l.compare(r)
			return order == .forward ? result : result.inverted
		}
	}
}

struct OptionalIntComparator: SortComparator {
	var order: SortOrder = .forward

	func compare(_ lhs: Int?, _ rhs: Int?) -> ComparisonResult {
		switch (lhs, rhs) {
		case (nil, nil):
			return .orderedSame
		case (nil, _):
			return order == .forward ? .orderedAscending : .orderedDescending
		case (_, nil):
			return order == .forward ? .orderedDescending : .orderedAscending
		case let (l?, r?):
			let result: ComparisonResult
			if l < r {
				result = .orderedAscending
			} else if l > r {
				result = .orderedDescending
			} else {
				result = .orderedSame
			}
			return order == .forward ? result : result.inverted
		}
	}
}

private extension ComparisonResult {

	var inverted: ComparisonResult {
		switch self {
		case .orderedAscending:
			return .orderedDescending
		case .orderedDescending:
			return .orderedAscending
		case .orderedSame:
			return .orderedSame
		}
	}
}
