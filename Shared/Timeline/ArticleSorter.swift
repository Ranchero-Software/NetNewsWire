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
	var sortableArticleID: String { get }
	var sortableFeedID: String { get }
}

struct ArticleSorter {
		
	static func sortedByDate<T: SortableArticle>(articles: [T],
												 sortDirection: ComparisonResult,
												 groupByFeed: Bool) -> [T] {
		if groupByFeed {
			return sortedByFeedName(articles: articles, sortByDateDirection: sortDirection)
		} else {
			return sortedByDate(articles: articles, sortDirection: sortDirection)
		}
	}
	
	// MARK: -
		
	private static func sortedByFeedName<T: SortableArticle>(articles: [T],
															 sortByDateDirection: ComparisonResult) -> [T] {
		// Group articles by feed - feed ID is used to differentiate between
		// two feeds that have the same name
		var groupedArticles = Dictionary(grouping: articles) { "\($0.sortableName.lowercased())-\($0.sortableFeedID)" }
		
		// Sort the articles within each group
		for tuple in groupedArticles {
			groupedArticles[tuple.key] = sortedByDate(articles: tuple.value,
													  sortDirection: sortByDateDirection)
		}
		
		// Flatten the articles dictionary back into an array sorted by feed name
		var sortedArticles: [T] = []
		for feedName in groupedArticles.keys.sorted() {
			sortedArticles.append(contentsOf: groupedArticles[feedName] ?? [])
		}
		
		return sortedArticles
	}
	
	private static func sortedByDate<T: SortableArticle>(articles: [T],
														 sortDirection: ComparisonResult) -> [T] {
		let articles = articles.sorted { (article1, article2) -> Bool in
			if article1.sortableDate == article2.sortableDate {
				return article1.sortableArticleID < article2.sortableArticleID
			}
			if sortDirection == .orderedDescending {
				return article1.sortableDate > article2.sortableDate
			}
			
			return article1.sortableDate < article2.sortableDate
		}
		return articles
	}
	
}
