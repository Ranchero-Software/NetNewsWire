//
//  ArticlesDatabase.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/20/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Database
import Parser
import Articles

// This file exists for compatibility — it provides nonisolated functions and callback-based APIs.
// It will go away as we adopt structured concurrency.

public typealias UpdateArticlesResult = Result<ArticleChanges, DatabaseError>
public typealias UpdateArticlesCompletionBlock = @Sendable (UpdateArticlesResult) -> Void

public typealias ArticleSetResult = Result<Set<Article>, DatabaseError>
public typealias ArticleSetResultBlock = (ArticleSetResult) -> Void

public typealias ArticleIDsResult = Result<Set<String>, DatabaseError>
public typealias ArticleIDsCompletionBlock = @Sendable (ArticleIDsResult) -> Void

public typealias ArticleStatusesResult = Result<Set<ArticleStatus>, DatabaseError>
public typealias ArticleStatusesResultBlock = (ArticleStatusesResult) -> Void

public extension ArticlesDatabase {

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

	// MARK: - Status

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
	
	nonisolated func mark(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping DatabaseCompletionBlock) {

		Task {
			do {
				try await mark(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
				callDatabaseCompletion(completion)
			} catch {
				callDatabaseCompletion(completion, .suspended)
			}
		}
	}

	nonisolated private func callUpdateArticlesCompletion(_ completion: @escaping UpdateArticlesCompletionBlock, _ result: UpdateArticlesResult) {

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
