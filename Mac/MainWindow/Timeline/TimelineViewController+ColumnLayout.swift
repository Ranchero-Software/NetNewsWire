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

		switch column {
		case .unread:
			let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? TimelineUnreadColumnCellView ?? makeCell(TimelineUnreadColumnCellView(), identifier: identifier)
			cell.isUnread = article.map { !$0.status.read } ?? false
			return cell

		case .starred:
			let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? TimelineStarColumnCellView ?? makeCell(TimelineStarColumnCellView(), identifier: identifier)
			cell.isStarred = article?.status.starred ?? false
			return cell

		case .title:
			let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? TimelineTextColumnCellView ?? makeCell(TimelineTextColumnCellView(), identifier: identifier)
			cell.textField?.font = columnFont
			cell.textField?.stringValue = article.map { columnTitleText(for: $0) } ?? ""
			return cell

		case .feed:
			let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? TimelineFeedColumnCellView ?? makeCell(TimelineFeedColumnCellView(), identifier: identifier)
			cell.textField?.font = columnFont
			cell.textField?.stringValue = article?.feed?.nameForDisplay ?? ""
			cell.imageView?.image = article?.feed.flatMap { IconImageCache.shared.imageForFeed($0) }?.image
			return cell

		case .date:
			let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? TimelineTextColumnCellView ?? makeCell(TimelineTextColumnCellView(), identifier: identifier)
			cell.textField?.font = columnFont
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
		guard let descriptor = tableView.sortDescriptors.first, let rawKey = descriptor.key, let key = ArticleSortKey(rawValue: rawKey) else {
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
		tableView.style = .inset
		tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
		tableView.allowsColumnReordering = false
		tableView.allowsColumnResizing = false
		tableView.rowHeight = standardRowHeight
	}

	func configureTableViewForColumnLayout() {
		removeAllTableColumns()
		for column in TimelineColumn.allCases {
			tableView.addTableColumn(column.makeTableColumn())
		}
		tableView.headerView = NSTableHeaderView()
		tableView.style = .fullWidth
		tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
		tableView.allowsColumnReordering = true
		tableView.allowsColumnResizing = true
		tableView.rowHeight = columnRowHeight()
		// Set the name before turning autosave on so saved widths and order are read back.
		tableView.autosaveName = columnAutosaveName
		tableView.autosaveTableColumns = true
		applySortDescriptorsToTableView()
	}

	/// An untitled article shows the start of its body instead, as the standard timeline does.
	func columnTitleText(for article: Article) -> String {
		let title = ArticleStringFormatter.shared.truncatedTitle(article)
		if !title.isEmpty {
			return title
		}
		let summary = ArticleStringFormatter.shared.truncatedSummary(article).collapsingWhitespace
		if !summary.isEmpty {
			return summary
		}
		return TimelineCellData.noText
	}

	func removeAllTableColumns() {
		for column in tableView.tableColumns {
			tableView.removeTableColumn(column)
		}
	}

	func makeCell<T: NSTableCellView>(_ cell: T, identifier: NSUserInterfaceItemIdentifier) -> T {
		cell.identifier = identifier
		return cell
	}
}
