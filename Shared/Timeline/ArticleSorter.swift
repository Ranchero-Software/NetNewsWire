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

	private static let titleCompareOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

	static func sorted(articles: [Article], parameters: ArticleSortParameters, feedNameFor: (Article) -> String = { $0.sortableFeedName }) -> [Article] {
		switch parameters.key {
		case .date:
			sortedByDate(articles: articles, sortDirection: parameters.direction, groupByFeed: parameters.effectiveGroupByFeed, feedNameFor: feedNameFor)
		case .feed:
			sortedByFeedName(articles: articles, sortDirection: .orderedDescending, feedNameDirection: parameters.direction, feedNameFor: feedNameFor)
		case .title:
			sortedByTitle(articles: articles, sortDirection: parameters.direction)
		case .unread:
			sortedByFlag(articles: articles, sortDirection: parameters.direction) { !$0.status.read }
		case .starred:
			sortedByFlag(articles: articles, sortDirection: parameters.direction) { $0.status.starred }
		}
	}

	static func sortedByDate(articles: [Article], sortDirection: ComparisonResult, groupByFeed: Bool, feedNameFor: (Article) -> String = { $0.sortableFeedName }) -> [Article] {
		if groupByFeed {
			sortedByFeedName(articles: articles, sortDirection: sortDirection, feedNameDirection: .orderedAscending, feedNameFor: feedNameFor)
		} else {
			sortedByDate(articles: articles, sortDirection: sortDirection)
		}
	}
}

// MARK: - Private

private extension ArticleSorter {

	static func sortedByFeedName(articles: [Article], sortDirection: ComparisonResult, feedNameDirection: ComparisonResult, feedNameFor: (Article) -> String) -> [Article] {
		// Group articles by feed ID so that two feeds with the same name remain in distinct groups.
		let groupedArticles = Dictionary(grouping: articles, by: \.feedID)
		let groupsWithNames = groupedArticles.map { (feedID: $0.key, name: feedNameFor($0.value[0]), articles: $0.value) }
		return groupsWithNames
			.sorted { lhs, rhs in
				switch lhs.name.localizedCaseInsensitiveCompare(rhs.name) {
				case .orderedAscending: feedNameDirection == .orderedAscending
				case .orderedDescending: feedNameDirection != .orderedAscending
				case .orderedSame: lhs.feedID < rhs.feedID
				}
			}
			.flatMap { sortedByDate(articles: $0.articles, sortDirection: sortDirection) }
	}

	static func sortedByDate(articles: [Article], sortDirection: ComparisonResult) -> [Article] {
		articles.sorted { article1, article2 in
			isOrderedByDate(article1, article2, sortDirection: sortDirection)
		}
	}

	static func sortedByTitle(articles: [Article], sortDirection: ComparisonResult) -> [Article] {
		articles.sorted { article1, article2 in
			let title1 = article1.title ?? ""
			let title2 = article2.title ?? ""
			return switch title1.compare(title2, options: titleCompareOptions, range: nil, locale: .current) {
			case .orderedAscending: sortDirection == .orderedAscending
			case .orderedDescending: sortDirection != .orderedAscending
			case .orderedSame: isOrderedByDate(article1, article2, sortDirection: .orderedDescending)
			}
		}
	}

	/// Descending puts articles with the flag set on top.
	static func sortedByFlag(articles: [Article], sortDirection: ComparisonResult, flag: (Article) -> Bool) -> [Article] {
		articles.sorted { article1, article2 in
			let flag1 = flag(article1)
			let flag2 = flag(article2)
			if flag1 == flag2 {
				return isOrderedByDate(article1, article2, sortDirection: .orderedDescending)
			}
			if sortDirection == .orderedDescending {
				return flag1
			}
			return flag2
		}
	}

	/// Ties on date are broken by articleID so the order is stable.
	static func isOrderedByDate(_ article1: Article, _ article2: Article, sortDirection: ComparisonResult) -> Bool {
		if article1.logicalDatePublished == article2.logicalDatePublished {
			article1.articleID < article2.articleID
		} else if sortDirection == .orderedDescending {
			article1.logicalDatePublished > article2.logicalDatePublished
		} else {
			article1.logicalDatePublished < article2.logicalDatePublished
		}
	}
}

// MARK: - Sorting

@MainActor extension Article {

	fileprivate var sortableFeedName: String {
		feed?.nameForDisplay ?? ""
	}
}
