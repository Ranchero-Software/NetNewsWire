//
//  TimelineViewController+ColumnLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/19/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit
import Articles

// The table view is shared by both layouts. These reconfigure it for the current one
// and supply the per-column cells used in column layout.

private let columnRowVerticalPadding: CGFloat = 3.0
private let columnAutosaveName = "TimelineColumns"

extension TimelineViewController {

	func configureTableView(for layout: TimelineLayout) {
		switch layout {
		case .standard:
			configureTableViewForStandardLayout()
		case .column:
			configureTableViewForColumnLayout()
		}
	}

	var columnFont: NSFont {
		NSFont.systemFont(ofSize: AppDefaults.shared.actualFontSize(for: AppDefaults.shared.timelineFontSize))
	}

	// Unread rows are bold, like Mail.
	var boldColumnFont: NSFont {
		NSFont.boldSystemFont(ofSize: AppDefaults.shared.actualFontSize(for: AppDefaults.shared.timelineFontSize))
	}

	func columnRowHeight() -> CGFloat {
		let font = columnFont
		let lineHeight = ceil(font.ascender - font.descender + font.leading)
		return lineHeight + (columnRowVerticalPadding * 2.0)
	}

	func columnCellView(for tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn, let column = TimelineColumn(identifier: tableColumn.identifier) else {
			return nil
		}
		let article = articles.articleAtRow(row)
		let identifier = tableColumn.identifier
		let isUnread = article.map { !$0.status.read } ?? false
		let textFont = isUnread ? boldColumnFont : columnFont

		switch column {
		case .unread:
			let cell = dequeueCell(TimelineUnreadColumnCellView.self, identifier: identifier)
			cell.isUnread = isUnread
			return cell

		case .starred:
			let cell = dequeueCell(TimelineStarColumnCellView.self, identifier: identifier)
			cell.isStarred = article?.status.starred ?? false
			return cell

		case .title:
			let cell = dequeueCell(TimelineTextColumnCellView.self, identifier: identifier)
			cell.textField?.font = textFont
			cell.textField?.stringValue = article.map { columnTitleText(for: $0) } ?? ""
			return cell

		case .feed:
			let cell = dequeueCell(TimelineFeedColumnCellView.self, identifier: identifier)
			cell.textField?.font = textFont
			cell.textField?.stringValue = article?.feed?.nameForDisplay ?? ""
			cell.imageView?.image = article?.feed.flatMap { IconImageCache.shared.imageForFeed($0) }?.image
			return cell

		case .date:
			let cell = dequeueCell(TimelineTextColumnCellView.self, identifier: identifier)
			cell.textField?.font = textFont
			cell.textField?.stringValue = article.map { ArticleStringFormatter.shared.dateString($0.logicalDatePublished) } ?? ""
			return cell
		}
	}

	/// Keeps the header’s sort indicator in step with this window’s sort. Column layout only.
	func applySortDescriptorsToTableView() {
		guard layout == .column else {
			return
		}
		let descriptors = [NSSortDescriptor(key: sortParameters.key.rawValue, ascending: sortParameters.direction == .orderedAscending)]
		if tableView.sortDescriptors != descriptors {
			tableView.sortDescriptors = descriptors
		}
	}

	// MARK: - NSTableViewDataSource

	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		// A header click. Don’t sort here — ask the container, which owns the window’s sort.
		// Setting sortDescriptors programmatically lands here too, and the equality check ends that loop.
		// The table also autosaves sort descriptors under its autosaveName and restores them when it’s configured.
		// Those belong to whatever window last saved, so they’re ignored — the window’s own sort is applied right after.
		guard !isConfiguringTableColumns, let descriptor = tableView.sortDescriptors.first, let rawKey = descriptor.key, let key = ArticleSortKey(rawValue: rawKey) else {
			return
		}
		let direction: ComparisonResult = descriptor.ascending ? .orderedAscending : .orderedDescending
		let requestedParameters = sortParameters.withKey(key, direction: direction)
		if requestedParameters == sortParameters {
			return
		}
		delegate?.timelineRequestedSortChange(self, parameters: requestedParameters)
	}
}

// MARK: - Private

private extension TimelineViewController {

	func configureTableViewForStandardLayout() {
		tableView.autosaveTableColumns = false
		tableView.autosaveName = nil
		tableView.sortDescriptors = []
		removeAllTableColumns()
		if let standardColumn {
			tableView.addTableColumn(standardColumn)
		}
		tableView.headerView = nil
		tableView.usesAlternatingRowBackgroundColors = false
		tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
		tableView.allowsColumnReordering = false
		tableView.allowsColumnResizing = false
		updateTableViewRowHeight()
	}

	func configureTableViewForColumnLayout() {
		isConfiguringTableColumns = true
		defer {
			isConfiguringTableColumns = false
		}
		removeAllTableColumns()
		for column in TimelineColumn.allCases {
			tableView.addTableColumn(column.makeTableColumn())
		}
		tableView.headerView = NSTableHeaderView()
		tableView.usesAlternatingRowBackgroundColors = true
		tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
		tableView.allowsColumnReordering = true
		tableView.allowsColumnResizing = true
		updateTableViewRowHeight()
		// Set the name before turning autosave on so saved widths and order are read back.
		tableView.autosaveName = columnAutosaveName
		tableView.autosaveTableColumns = true
		isConfiguringTableColumns = false
		applySortDescriptorsToTableView()
	}

	/// An untitled article shows the start of its body instead, as the standard timeline does.
	func columnTitleText(for article: Article) -> String {
		let title = ArticleStringFormatter.shared.truncatedTitle(article)
		if !title.isEmpty {
			return title
		}
		return TimelineCellData.summaryText(for: article, title: title).collapsingWhitespace
	}

	func removeAllTableColumns() {
		for column in tableView.tableColumns {
			tableView.removeTableColumn(column)
		}
	}

	func dequeueCell<T: NSTableCellView>(_ type: T.Type, identifier: NSUserInterfaceItemIdentifier) -> T {
		if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? T {
			return cell
		}
		let cell = T()
		cell.identifier = identifier
		return cell
	}
}
