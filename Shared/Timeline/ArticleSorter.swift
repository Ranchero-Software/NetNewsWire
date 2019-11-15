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
	var sortableWebFeedID: String { get }
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
		// Group articles by "feed-feedID" - feed ID is used to differentiate between
		// two feeds that have the same name
		let groupedArticles = Dictionary(grouping: articles) { "\($0.sortableName.lowercased())-\($0.sortableWebFeedID)" }
		return groupedArticles
			.sorted { $0.key < $1.key }
			.flatMap { (tuple) -> [T] in
				let (_, articles) = tuple
				
				return sortedByDate(articles: articles, sortDirection: sortByDateDirection)
		}
	}
	
	private static func sortedByDate<T: SortableArticle>(articles: [T],
														 sortDirection: ComparisonResult) -> [T] {
		return articles.sorted { (article1, article2) -> Bool in
			if article1.sortableDate == article2.sortableDate {
				return article1.sortableArticleID < article2.sortableArticleID
			}
			if sortDirection == .orderedDescending {
				return article1.sortableDate > article2.sortableDate
			}
			
			return article1.sortableDate < article2.sortableDate
		}
	}
	
}
