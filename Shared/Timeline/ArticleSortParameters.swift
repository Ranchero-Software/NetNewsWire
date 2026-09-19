//
//  ArticleSortParameters.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/18/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation

/// The column a timeline is sorted by. Raw values double as table column identifiers and sort descriptor keys.
enum ArticleSortKey: String, CaseIterable, Sendable {
	case date
	case title
	case feed
	case unread
	case starred
}

/// How one timeline is sorted. Each main window has its own.
struct ArticleSortParameters: Equatable, Sendable {

	let key: ArticleSortKey
	let direction: ComparisonResult
	let groupByFeed: Bool

	static let newestFirst = ArticleSortParameters(key: .date, direction: .orderedDescending, groupByFeed: false)

	init(key: ArticleSortKey, direction: ComparisonResult, groupByFeed: Bool) {
		self.key = key
		self.direction = direction
		self.groupByFeed = groupByFeed
	}

	/// Group by feed only makes sense when sorting by date.
	var effectiveGroupByFeed: Bool {
		key == .date && groupByFeed
	}

	func withKey(_ key: ArticleSortKey, direction: ComparisonResult) -> ArticleSortParameters {
		ArticleSortParameters(key: key, direction: direction, groupByFeed: groupByFeed)
	}

	func withGroupByFeed(_ groupByFeed: Bool) -> ArticleSortParameters {
		ArticleSortParameters(key: key, direction: direction, groupByFeed: groupByFeed)
	}
}
