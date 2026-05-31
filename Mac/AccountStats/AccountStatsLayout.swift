//
//  AccountStatsLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/7/26.
//

import AppKit

enum AccountStatsLayout {

	static let windowDefaultWidth: CGFloat = 840
	// Wide enough to fit all NSTableView columns at their initial widths plus inset-style
	// chrome, intercell spacing, vertical scroller, and header padding. Clamps any prior
	// narrow autosaved frame on next open.
	static let windowMinWidth: CGFloat = 780
	static let windowMinHeight: CGFloat = 260
	static let windowDefaultHeight: CGFloat = 460
	static let horizontalPadding: CGFloat = 16
	static let verticalSpacing: CGFloat = 12
	static let buttonWidth: CGFloat = 160
	static let bottomBarFontSize: CGFloat = 16 // matches Activity Log / Error Log warning labels

	static func formattedNumber(_ value: Int) -> String {
		NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
	}

	static func formattedSize(_ bytes: Int) -> String {
		Int64(bytes).formatted(.byteCount(style: .file))
	}
}
