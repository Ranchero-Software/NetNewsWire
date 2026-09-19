//
//  TimelineColumn.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/19/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit

/// The columns of the timeline in column layout, in default order.
enum TimelineColumn: String, CaseIterable {
	case unread
	case starred
	case feed
	case title
	case date

	private static let statusColumnWidth: CGFloat = 22.0
	private static let titleColumnWidth: CGFloat = 400.0
	private static let titleColumnMinimumWidth: CGFloat = 100.0
	private static let feedColumnWidth: CGFloat = 180.0
	private static let feedColumnMinimumWidth: CGFloat = 80.0
	private static let dateColumnWidth: CGFloat = 130.0
	private static let dateColumnMinimumWidth: CGFloat = 70.0
	private static let textColumnMaximumWidth: CGFloat = 2000.0

	var identifier: NSUserInterfaceItemIdentifier {
		NSUserInterfaceItemIdentifier(rawValue: rawValue)
	}

	init?(identifier: NSUserInterfaceItemIdentifier) {
		self.init(rawValue: identifier.rawValue)
	}

	var sortKey: ArticleSortKey {
		switch self {
		case .unread:
			.unread
		case .starred:
			.starred
		case .title:
			.title
		case .feed:
			.feed
		case .date:
			.date
		}
	}

	/// The status columns have no header text — just a tooltip.
	var headerTitle: String {
		switch self {
		case .unread, .starred:
			""
		case .title:
			NSLocalizedString("Title", comment: "Timeline column header")
		case .feed:
			NSLocalizedString("Feed", comment: "Timeline column header")
		case .date:
			NSLocalizedString("Date", comment: "Timeline column header")
		}
	}

	/// Only the status columns need one — their headers have no text.
	var headerToolTip: String? {
		switch self {
		case .unread:
			NSLocalizedString("Unread", comment: "Unread")
		case .starred:
			NSLocalizedString("Starred", comment: "Starred")
		case .title, .feed, .date:
			nil
		}
	}

	/// Direction used the first time the user clicks the header. Newest, unread, and starred go on top.
	var sortsAscendingFirst: Bool {
		switch self {
		case .title, .feed:
			true
		case .unread, .starred, .date:
			false
		}
	}

	@MainActor func makeTableColumn() -> NSTableColumn {
		let column = NSTableColumn(identifier: identifier)
		column.headerCell = TimelineColumnHeaderCell(textCell: headerTitle)
		column.headerToolTip = headerToolTip
		column.sortDescriptorPrototype = NSSortDescriptor(key: sortKey.rawValue, ascending: sortsAscendingFirst)

		switch self {
		case .unread, .starred:
			column.width = Self.statusColumnWidth
			column.minWidth = Self.statusColumnWidth
			column.maxWidth = Self.statusColumnWidth
			column.resizingMask = []
		case .title:
			column.width = Self.titleColumnWidth
			column.minWidth = Self.titleColumnMinimumWidth
			column.maxWidth = Self.textColumnMaximumWidth
			// The only column that absorbs window resizing.
			column.resizingMask = [.userResizingMask, .autoresizingMask]
		case .feed:
			column.width = Self.feedColumnWidth
			column.minWidth = Self.feedColumnMinimumWidth
			column.maxWidth = Self.textColumnMaximumWidth
			column.resizingMask = .userResizingMask
		case .date:
			column.width = Self.dateColumnWidth
			column.minWidth = Self.dateColumnMinimumWidth
			column.maxWidth = Self.textColumnMaximumWidth
			column.resizingMask = .userResizingMask
		}

		return column
	}
}

/// Adds a little room between the column separator and the title, as Mail has.
final class TimelineColumnHeaderCell: NSTableHeaderCell {

	private static let titleLeftPadding: CGFloat = 6.0

	override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
		var frame = cellFrame
		frame.origin.x += Self.titleLeftPadding
		frame.size.width -= Self.titleLeftPadding
		super.drawInterior(withFrame: frame, in: controlView)
	}
}
