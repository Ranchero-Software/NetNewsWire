//
//  ArticleSortParameters.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/18/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation

/// The field a timeline is sorted by. Raw values double as table column identifiers, sort descriptor keys, and menu item identifiers.
enum ArticleSortKey: String, Sendable {
	case date
	case feed
	case title
	case unread
	case starred

	var localizedName: String {
		switch self {
		case .date:
			NSLocalizedString("Date", comment: "Timeline column header")
		case .feed:
			NSLocalizedString("Feed", comment: "Timeline column header")
		case .title:
			NSLocalizedString("Title", comment: "Timeline column header")
		case .unread:
			NSLocalizedString("Unread", comment: "Unread")
		case .starred:
			NSLocalizedString("Starred", comment: "Starred")
		}
	}

	/// Menu title for a direction, worded for the field: dates by age, text alphabetically, flags ascending or descending.
	func localizedDirectionTitle(ascending: Bool) -> String {
		let ascendingTitle: String
		let descendingTitle: String
		switch self {
		case .date:
			ascendingTitle = NSLocalizedString("Oldest Article on Top", comment: "Sort direction")
			descendingTitle = NSLocalizedString("Newest Article on Top", comment: "Sort direction")
		case .feed, .title:
			ascendingTitle = NSLocalizedString("A to Z", comment: "Sort direction")
			descendingTitle = NSLocalizedString("Z to A", comment: "Sort direction")
		case .unread, .starred:
			ascendingTitle = NSLocalizedString("Ascending", comment: "Sort direction")
			descendingTitle = NSLocalizedString("Descending", comment: "Sort direction")
		}
		return ascending ? ascendingTitle : descendingTitle
	}

	/// Direction used the first time a field is chosen. Newest, unread, and starred go on top.
	var sortsAscendingFirst: Bool {
		switch self {
		case .feed, .title:
			true
		case .date, .unread, .starred:
			false
		}
	}

	var firstDirection: ComparisonResult {
		sortsAscendingFirst ? .orderedAscending : .orderedDescending
	}
}

/// How one timeline is sorted. Each main window has its own. Every field but date uses date, newest first, as the secondary sort.
struct ArticleSortParameters: Equatable, Sendable {

	let key: ArticleSortKey
	let direction: ComparisonResult

	static let newestFirst = ArticleSortParameters(key: .date, direction: .orderedDescending)

	func withKey(_ key: ArticleSortKey, direction: ComparisonResult) -> ArticleSortParameters {
		ArticleSortParameters(key: key, direction: direction)
	}

	func withDirection(_ direction: ComparisonResult) -> ArticleSortParameters {
		ArticleSortParameters(key: key, direction: direction)
	}
}
