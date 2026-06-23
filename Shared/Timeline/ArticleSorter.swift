//
//  ArticleSorter.swift
//  NetNewsWire
//
//  Created by Phil Viso on 9/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Articles

@MainActor struct ArticleSorter {

	static func sortedByDate(articles: [Article], sortDirection: ComparisonResult, groupByFeed: Bool, feedNameFor: (Article) -> String = { $0.sortableFeedName }) -> [Article] {
		if groupByFeed {
			sortedByFeedName(articles: articles, sortDirection: sortDirection, feedNameFor: feedNameFor)
		} else {
			sortedByDate(articles: articles, sortDirection: sortDirection)
		}
	}
}

// MARK: - Private

private extension ArticleSorter {

	static func sortedByFeedName(articles: [Article], sortDirection: ComparisonResult, feedNameFor: (Article) -> String) -> [Article] {
		// Group articles by feed ID so that two feeds with the same name remain in distinct groups.
		let groupedArticles = Dictionary(grouping: articles, by: \.feedID)
		let groupsWithNames = groupedArticles.map { (feedID: $0.key, name: feedNameFor($0.value[0]), articles: $0.value) }
		return groupsWithNames
			.sorted { lhs, rhs in
				switch lhs.name.localizedCaseInsensitiveCompare(rhs.name) {
				case .orderedAscending: true
				case .orderedDescending: false
				case .orderedSame: lhs.feedID < rhs.feedID
				}
			}
			.flatMap { sortedByDate(articles: $0.articles, sortDirection: sortDirection) }
	}

	static func sortedByDate(articles: [Article], sortDirection: ComparisonResult) -> [Article] {
		articles.sorted { article1, article2 in
			if article1.logicalDatePublished == article2.logicalDatePublished {
				article1.articleID < article2.articleID
			} else if sortDirection == .orderedDescending {
				article1.logicalDatePublished > article2.logicalDatePublished
			} else {
				article1.logicalDatePublished < article2.logicalDatePublished
			}
		}
	}
}

// MARK: - Sorting

@MainActor extension Article {

	fileprivate var sortableFeedName: String {
		feed?.nameForDisplay ?? ""
	}
}
