//
//  ArticlesDatabase.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Database
import RSParser
import Articles

// This file exists for compatibility — it provides nonisolated functions and callback-based APIs.
// It will go away as we adopt structured concurrency.

public typealias UnreadCountDictionaryCompletionResult = Result<UnreadCountDictionary,DatabaseError>
public typealias UnreadCountDictionaryCompletionBlock = @Sendable (UnreadCountDictionaryCompletionResult) -> Void

public typealias SingleUnreadCountResult = Result<Int, DatabaseError>
public typealias SingleUnreadCountCompletionBlock = @Sendable (SingleUnreadCountResult) -> Void

public typealias UpdateArticlesResult = Result<ArticleChanges, DatabaseError>
public typealias UpdateArticlesCompletionBlock = @Sendable (UpdateArticlesResult) -> Void

public typealias ArticleSetResult = Result<Set<Article>, DatabaseError>
public typealias ArticleSetResultBlock = (ArticleSetResult) -> Void

public typealias ArticleIDsResult = Result<Set<String>, DatabaseError>
public typealias ArticleIDsCompletionBlock = @Sendable (ArticleIDsResult) -> Void

public typealias ArticleStatusesResult = Result<Set<ArticleStatus>, DatabaseError>
public typealias ArticleStatusesResultBlock = (ArticleStatusesResult) -> Void

public extension ArticlesDatabase {

	// MARK: - Fetching Articles Async

	nonisolated func fetchArticlesAsync(_ feedID: String, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await articles(feedID: feedID)
				completion(.success(articles))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func fetchArticlesAsync(_ feedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await articles(feedIDs: feedIDs)
				completion(.success(articles))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func fetchArticlesAsync(articleIDs: Set<String>, _ completion: @escaping  ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await articles(articleIDs: articleIDs)
				completion(.success(articles))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func fetchUnreadArticlesAsync(_ feedIDs: Set<String>, _ limit: Int?, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await unreadArticles(feedIDs: feedIDs, limit: limit)
				completion(.success(articles))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func fetchTodayArticlesAsync(_ feedIDs: Set<String>, _ limit: Int?, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await todayArticles(feedIDs: feedIDs, limit: limit)
				completion(.success(articles))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func fetchedStarredArticlesAsync(_ feedIDs: Set<String>, _ limit: Int?, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await starredArticles(feedIDs: feedIDs, limit: limit)
				completion(.success(articles))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func fetchArticlesMatchingAsync(_ searchString: String, _ feedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await articlesMatching(searchString: searchString, feedIDs: feedIDs)
				completion(.success(articles))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func fetchArticlesMatchingWithArticleIDsAsync(_ searchString: String, _ articleIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await articlesMatching(searchString: searchString, articleIDs: articleIDs)
				completion(.success(articles))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	// MARK: - Unread Counts

	/// Fetch all non-zero unread counts.
	nonisolated func fetchAllUnreadCounts(_ completion: @escaping UnreadCountDictionaryCompletionBlock) {

		Task {
			do {
				let unreadCountDictionary = try await allUnreadCounts()
				completion(.success(unreadCountDictionary))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	/// Fetch unread count for a single feed.
	nonisolated func fetchUnreadCount(_ feedID: String, _ completion: @escaping SingleUnreadCountCompletionBlock) {

		Task {
			do {
				let unreadCount = try await unreadCount(feedID: feedID) ?? 0
				completion(.success(unreadCount))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	/// Fetch non-zero unread counts for given feedIDs.
	nonisolated func fetchUnreadCounts(for feedIDs: Set<String>, _ completion: @escaping UnreadCountDictionaryCompletionBlock) {

		Task {
			do {
				let unreadCountDictionary = try await unreadCounts(feedIDs: feedIDs)
				completion(.success(unreadCountDictionary))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func fetchUnreadCountForToday(for feedIDs: Set<String>, completion: @escaping SingleUnreadCountCompletionBlock) {

		Task {
			do {
				let unreadCount = try await unreadCountForToday(feedIDs: feedIDs)!
				completion(.success(unreadCount))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func fetchUnreadCount(for feedIDs: Set<String>, since: Date, completion: @escaping SingleUnreadCountCompletionBlock) {

		Task {
			do {
				let unreadCount = try await unreadCount(feedIDs: feedIDs, since: since)!
				completion(.success(unreadCount))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func fetchStarredAndUnreadCount(for feedIDs: Set<String>, completion: @escaping SingleUnreadCountCompletionBlock) {

		Task {
			do {
				let unreadCount = try await starredAndUnreadCount(feedIDs: feedIDs)!
				completion(.success(unreadCount))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	// MARK: - Saving, Updating, and Deleting Articles

	/// Update articles and save new ones — for feed-based systems (local and iCloud).
	nonisolated func update(with parsedItems: Set<ParsedItem>, feedID: String, deleteOlder: Bool, completion: @escaping UpdateArticlesCompletionBlock) {

		Task {
			do {
				let articleChanges = try await update(parsedItems: parsedItems, feedID: feedID, deleteOlder: deleteOlder)
				completion(.success(articleChanges))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	/// Update articles and save new ones — for sync systems (Feedbin, Feedly, etc.).
	nonisolated func update(feedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool, completion: @escaping UpdateArticlesCompletionBlock) {

		Task {
			do {
				let articleChanges = try await update(feedIDsAndItems: feedIDsAndItems, defaultRead: defaultRead)
				completion(.success(articleChanges))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	/// Delete articles
	nonisolated func delete(articleIDs: Set<String>, completion: DatabaseCompletionBlock?) {

		Task {
			do {
				try await delete(articleIDs: articleIDs)
				completion?(nil)
			} catch {
				completion?(.suspended)
			}
		}
	}

	// MARK: - Status

	/// Fetch the articleIDs of unread articles.
	nonisolated func fetchUnreadArticleIDsAsync(completion: @escaping ArticleIDsCompletionBlock) {

		Task {
			do {
				let articleIDs = try await unreadArticleIDs()!
				completion(.success(articleIDs))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	/// Fetch the articleIDs of starred articles.
	nonisolated func fetchStarredArticleIDsAsync(completion: @escaping ArticleIDsCompletionBlock) {

		Task {
			do {
				let articleIDs = try await starredArticleIDs()!
				completion(.success(articleIDs))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	/// Fetch articleIDs for articles that we should have, but don’t. These articles are either (starred) or (newer than the article cutoff date).
	nonisolated func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(_ completion: @escaping ArticleIDsCompletionBlock) {

		Task {
			do {
				let articleIDs = try await articleIDsForStatusesWithoutArticlesNewerThanCutoffDate()!
				completion(.success(articleIDs))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func mark(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping ArticleStatusesResultBlock) {

		Task {
			do {
				let statuses = try await mark(articles: articles, statusKey: statusKey, flag: flag)!
				completion(.success(statuses))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	nonisolated func markAndFetchNew(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping ArticleIDsCompletionBlock) {

		Task {
			do {
				let statuses = try await markAndFetchNew(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
				completion(.success(statuses))
			} catch {
				completion(.failure(.suspended))
			}
		}
	}

	/// Create statuses for specified articleIDs. For existing statuses, don’t do anything.
	/// For newly-created statuses, mark them as read and not-starred.
	nonisolated func createStatusesIfNeeded(articleIDs: Set<String>, completion: @escaping DatabaseCompletionBlock) {

		Task {
			do {
				try await createStatusesIfNeeded(articleIDs: articleIDs)
				completion(nil)
			} catch {
				completion(.suspended)
			}
		}
	}
}
