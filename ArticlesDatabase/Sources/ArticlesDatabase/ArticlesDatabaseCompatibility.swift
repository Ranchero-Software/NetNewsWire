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

	nonisolated private func callUpdateArticlesCompletion(_ completion: @escaping UpdateArticlesCompletionBlock, _ result: UpdateArticlesResult) {

		Task { @MainActor in
			completion(result)
		}
	}
}
