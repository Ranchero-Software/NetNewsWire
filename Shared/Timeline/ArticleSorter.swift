//
//  ArticleSorter.swift
//  NetNewsWire
//
//  Created by Phil Viso on 9/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Articles
import Foundation

protocol SortableArticle {
	var sortableName: String { get }
	var sortableDate: Date { get }
	var sortableID: String { get }
}

struct ArticleSorter {
	
	static func sortedByDate<T: SortableArticle>(articles: [T],
												 sortDirection: ComparisonResult,
												 groupByFeed: Bool) -> [T] {
		let articles = articles.sorted { (article1, article2) -> Bool in
			if groupByFeed {
				let feedName1 = article1.sortableName
				let feedName2 = article2.sortableName
				
				let comparison = feedName1.caseInsensitiveCompare(feedName2)
				switch comparison {
				case .orderedSame:
					return isSortedByDate(article1, article2, sortDirection: sortDirection)
				case .orderedAscending, .orderedDescending:
					return comparison == .orderedAscending
				}
			} else {
				return isSortedByDate(article1, article2, sortDirection: sortDirection)
			}
		}
		
		return articles
	}
	
	// MARK: -
	
	private static func isSortedByDate(_ lhs: SortableArticle,
									   _ rhs: SortableArticle,
									   sortDirection: ComparisonResult) -> Bool {
		if lhs.sortableDate == rhs.sortableDate {
			return lhs.sortableID < rhs.sortableID
		}
		if sortDirection == .orderedDescending {
			return lhs.sortableDate > rhs.sortableDate
		}
		return lhs.sortableDate < rhs.sortableDate
	}
	
}
