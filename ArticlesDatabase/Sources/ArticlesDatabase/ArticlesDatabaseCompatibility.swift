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
				callArticleSetCompletion(completion, .success(articles))
			} catch {
				callArticleSetCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func fetchArticlesAsync(_ feedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await articles(feedIDs: feedIDs)
				callArticleSetCompletion(completion, .success(articles))
			} catch {
				callArticleSetCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func fetchArticlesAsync(articleIDs: Set<String>, _ completion: @escaping  ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await articles(articleIDs: articleIDs)
				callArticleSetCompletion(completion, .success(articles))
			} catch {
				callArticleSetCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func fetchUnreadArticlesAsync(_ feedIDs: Set<String>, _ limit: Int?, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await unreadArticles(feedIDs: feedIDs, limit: limit)
				callArticleSetCompletion(completion, .success(articles))
			} catch {
				callArticleSetCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func fetchTodayArticlesAsync(_ feedIDs: Set<String>, _ limit: Int?, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await todayArticles(feedIDs: feedIDs, limit: limit)
				callArticleSetCompletion(completion, .success(articles))
			} catch {
				callArticleSetCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func fetchedStarredArticlesAsync(_ feedIDs: Set<String>, _ limit: Int?, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await starredArticles(feedIDs: feedIDs, limit: limit)
				callArticleSetCompletion(completion, .success(articles))
			} catch {
				callArticleSetCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func fetchArticlesMatchingAsync(_ searchString: String, _ feedIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await articlesMatching(searchString: searchString, feedIDs: feedIDs)
				callArticleSetCompletion(completion, .success(articles))
			} catch {
				callArticleSetCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func fetchArticlesMatchingWithArticleIDsAsync(_ searchString: String, _ articleIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {

		Task {
			do {
				let articles = try await articlesMatching(searchString: searchString, articleIDs: articleIDs)
				callArticleSetCompletion(completion, .success(articles))
			} catch {
				callArticleSetCompletion(completion, .failure(.suspended))
			}
		}
	}

	// MARK: - Unread Counts

	/// Fetch all non-zero unread counts.
	nonisolated func fetchAllUnreadCounts(_ completion: @escaping UnreadCountDictionaryCompletionBlock) {

		Task {
			do {
				let unreadCountDictionary = try await allUnreadCounts()
				callUnreadCountDictionaryCompletion(completion, .success(unreadCountDictionary))
			} catch {
				callUnreadCountDictionaryCompletion(completion, .failure(.suspended))
			}
		}
	}

	/// Fetch unread count for a single feed.
	nonisolated func fetchUnreadCount(_ feedID: String, _ completion: @escaping SingleUnreadCountCompletionBlock) {

		Task {
			do {
				let unreadCount = try await unreadCount(feedID: feedID) ?? 0
				callSingleUnreadCountCompletion(completion, .success(unreadCount))
			} catch {
				callSingleUnreadCountCompletion(completion, .failure(.suspended))
			}
		}
	}

	/// Fetch non-zero unread counts for given feedIDs.
	nonisolated func fetchUnreadCounts(for feedIDs: Set<String>, _ completion: @escaping UnreadCountDictionaryCompletionBlock) {

		Task {
			do {
				let unreadCountDictionary = try await unreadCounts(feedIDs: feedIDs)
				callUnreadCountDictionaryCompletion(completion, .success(unreadCountDictionary))
			} catch {
				callUnreadCountDictionaryCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func fetchUnreadCountForToday(for feedIDs: Set<String>, completion: @escaping SingleUnreadCountCompletionBlock) {

		Task {
			do {
				let unreadCount = try await unreadCountForToday(feedIDs: feedIDs)!
				callSingleUnreadCountCompletion(completion, .success(unreadCount))
			} catch {
				callSingleUnreadCountCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func fetchUnreadCount(for feedIDs: Set<String>, since: Date, completion: @escaping SingleUnreadCountCompletionBlock) {

		Task {
			do {
				let unreadCount = try await unreadCount(feedIDs: feedIDs, since: since)!
				callSingleUnreadCountCompletion(completion, .success(unreadCount))
			} catch {
				callSingleUnreadCountCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func fetchStarredAndUnreadCount(for feedIDs: Set<String>, completion: @escaping SingleUnreadCountCompletionBlock) {

		Task {
			do {
				let unreadCount = try await starredAndUnreadCount(feedIDs: feedIDs)!
				callSingleUnreadCountCompletion(completion, .success(unreadCount))
			} catch {
				callSingleUnreadCountCompletion(completion, .failure(.suspended))
			}
		}
	}

	// MARK: - Saving, Updating, and Deleting Articles

	/// Update articles and save new ones — for feed-based systems (local and iCloud).
	nonisolated func update(with parsedItems: Set<ParsedItem>, feedID: String, deleteOlder: Bool, completion: @escaping UpdateArticlesCompletionBlock) {

		Task {
			do {
				let articleChanges = try await update(parsedItems: parsedItems, feedID: feedID, deleteOlder: deleteOlder)
				callUpdateArticlesCompletion(completion, .success(articleChanges))
			} catch {
				callUpdateArticlesCompletion(completion, .failure(.suspended))
			}
		}
	}

	/// Update articles and save new ones — for sync systems (Feedbin, Feedly, etc.).
	nonisolated func update(feedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool, completion: @escaping UpdateArticlesCompletionBlock) {

		Task {
			do {
				let articleChanges = try await update(feedIDsAndItems: feedIDsAndItems, defaultRead: defaultRead)
				callUpdateArticlesCompletion(completion, .success(articleChanges))
			} catch {
				callUpdateArticlesCompletion(completion, .failure(.suspended))
			}
		}
	}

	/// Delete articles
	nonisolated func delete(articleIDs: Set<String>, completion: DatabaseCompletionBlock?) {

		Task {
			do {
				try await delete(articleIDs: articleIDs)
				callDatabaseCompletion(completion)
			} catch {
				callDatabaseCompletion(completion, .suspended)
			}
		}
	}

	// MARK: - Status

	/// Fetch the articleIDs of unread articles.
	nonisolated func fetchUnreadArticleIDsAsync(completion: @escaping ArticleIDsCompletionBlock) {

		Task {
			do {
				let articleIDs = try await unreadArticleIDs()!
				callArticleIDsCompletion(completion, .success(articleIDs))
			} catch {
				callArticleIDsCompletion(completion, .failure(.suspended))
			}
		}
	}

	/// Fetch the articleIDs of starred articles.
	nonisolated func fetchStarredArticleIDsAsync(completion: @escaping ArticleIDsCompletionBlock) {

		Task {
			do {
				let articleIDs = try await starredArticleIDs()!
				callArticleIDsCompletion(completion, .success(articleIDs))
			} catch {
				callArticleIDsCompletion(completion, .failure(.suspended))
			}
		}
	}

	/// Fetch articleIDs for articles that we should have, but don’t. These articles are either (starred) or (newer than the article cutoff date).
	nonisolated func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(_ completion: @escaping ArticleIDsCompletionBlock) {
		
		Task {
			do {
				let articleIDs = try await articleIDsForStatusesWithoutArticlesNewerThanCutoffDate()!
				callArticleIDsCompletion(completion, .success(articleIDs))
			} catch {
				callArticleIDsCompletion(completion, .failure(.suspended))
			}
		}
	}

	nonisolated func mark(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping ArticleStatusesResultBlock) {
		
		Task {
			do {
				let statuses = try await mark(articles: articles, statusKey: statusKey, flag: flag)!
				callArticleStatusesCompletion(completion, .success(statuses))
			} catch {
				callArticleStatusesCompletion(completion, .failure(.suspended))
			}
		}
	}
	
	nonisolated func markAndFetchNew(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping ArticleIDsCompletionBlock) {

		Task {
			do {
				let statuses = try await markAndFetchNew(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
				callArticleIDsCompletion(completion, .success(statuses))
			} catch {
				callArticleIDsCompletion(completion, .failure(.suspended))
			}
		}
	}

	/// Create statuses for specified articleIDs. For existing statuses, don’t do anything.
	/// For newly-created statuses, mark them as read and not-starred.
	nonisolated func createStatusesIfNeeded(articleIDs: Set<String>, completion: @escaping DatabaseCompletionBlock) {

		Task {
			do {
				try await createStatusesIfNeeded(articleIDs: articleIDs)
				callDatabaseCompletion(completion)
			} catch {
				callDatabaseCompletion(completion, .suspended)
			}
		}
	}

	nonisolated private func callUnreadCountDictionaryCompletion(_ completion: @escaping UnreadCountDictionaryCompletionBlock, _ result: UnreadCountDictionaryCompletionResult) {

		Task { @MainActor in
			completion(result)
		}
	}

	nonisolated private func callSingleUnreadCountCompletion(_ completion: @escaping SingleUnreadCountCompletionBlock, _ result: SingleUnreadCountResult) {

		Task { @MainActor in
			completion(result)
		}
	}

	nonisolated private func callUpdateArticlesCompletion(_ completion: @escaping UpdateArticlesCompletionBlock, _ result: UpdateArticlesResult) {

		Task { @MainActor in
			completion(result)
		}
	}

	nonisolated private func callArticleSetCompletion(_ completion: @escaping ArticleSetResultBlock, _ result: ArticleSetResult) {

		Task { @MainActor in
			completion(result)
		}
	}

	nonisolated private func callArticleStatusesCompletion(_ completion: @escaping ArticleStatusesResultBlock, _ result: ArticleStatusesResult) {

		Task { @MainActor in
			completion(result)
		}
	}

	nonisolated private func callArticleIDsCompletion(_ completion: @escaping ArticleIDsCompletionBlock, _ result: ArticleIDsResult) {

		Task { @MainActor in
			completion(result)
		}
	}

	nonisolated private func callDatabaseCompletion(_ completion: DatabaseCompletionBlock?, _ error: DatabaseError? = nil) {

		guard let completion else {
			return
		}
		
		Task { @MainActor in
			completion(error)
		}
	}
}
