//
//  AuthorsSchemaMigration.swift
//  ArticlesDatabase
//
//  Created by Brent Simmons on 4/29/26.
//

import Foundation
import os
import RSDatabase
import RSDatabaseObjC
import Articles

/// One-time migration: populate the `articles.authors` JSON column from the
/// legacy `authors` and `authorsLookup` tables. Idempotent (only processes
/// articles whose `authors` column is still NULL) and resumable (each batch
/// is its own transaction).
///
/// Runs cooperatively: each iteration fetches up to 500 articleIDs needing
/// migration, backfills them, then sleeps briefly so other database work
/// (fetches, updates) can interleave on the queue. Re-fetching every batch
/// also picks up newly-arrived articles that still need migrating.
struct AuthorsSchemaMigration: Sendable {

	let accountID: String
	let queue: DatabaseQueue

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AuthorsSchemaMigration")

	func run() async {
		let startTime = Date()
		var totalCount = 0
		var didLogStart = false

		while true {
			let batch = await fetchNextBatch(limit: 500)
			if batch.isEmpty {
				break
			}

			if !didLogStart {
				Self.logger.info("AuthorsSchemaMigration: starting in account \(self.accountID, privacy: .public)")
				didLogStart = true
			}

			await backfillBatch(batch)
			totalCount += batch.count

			try? await Task.sleep(for: .milliseconds(100))
		}

		if didLogStart {
			let elapsed = Date().timeIntervalSince(startTime)
			Self.logger.info("AuthorsSchemaMigration: finished for \(totalCount, privacy: .public) articles in account \(self.accountID, privacy: .public) — \(elapsed, privacy: .public) seconds")
		}
	}
}

private extension AuthorsSchemaMigration {

	func fetchNextBatch(limit: Int) async -> Set<String> {
		await withCheckedContinuation { continuation in
			queue.runInDatabase { result in
				guard let database = try? result.get(), database.tableExists("authorsLookup") else {
					continuation.resume(returning: Set<String>())
					return
				}
				// Inner-join on authors so articles whose lookup entries are all orphaned
				// (no matching authors row) don't keep matching forever.
				let sql = "select distinct lookup.articleID from authorsLookup lookup inner join articles on articles.articleID = lookup.articleID inner join authors on authors.authorID = lookup.authorID where articles.authors is null limit ?;"
				guard let resultSet = database.executeQuery(sql, withArgumentsIn: [limit]) else {
					continuation.resume(returning: Set<String>())
					return
				}
				var ids = Set<String>()
				while resultSet.next() {
					if let articleID = resultSet.swiftString(forColumn: DatabaseKey.articleID) {
						ids.insert(articleID)
					}
				}
				resultSet.close()
				continuation.resume(returning: ids)
			}
		}
	}

	func backfillBatch(_ articleIDs: Set<String>) async {
		await withCheckedContinuation { continuation in
			queue.runInDatabase { result in
				guard let database = try? result.get() else {
					continuation.resume()
					return
				}
				let authorsByArticleID = fetchAuthorsByArticleID(articleIDs, database: database)
				if authorsByArticleID.isEmpty {
					continuation.resume()
					return
				}
				database.beginTransaction()
				for (articleID, authors) in authorsByArticleID {
					guard !authors.isEmpty, let json = authors.json() else {
						continue
					}
					database.executeUpdate("update articles set authors = ? where articleID = ?;", withArgumentsIn: [json, articleID])
				}
				database.commit()
				continuation.resume()
			}
		}
	}

	func fetchAuthorsByArticleID(_ articleIDs: Set<String>, database: FMDatabase) -> [String: Set<Author>] {
		guard !articleIDs.isEmpty,
		      let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count)) else {
			return [:]
		}
		let sql = "select lookup.articleID, authors.authorID, authors.name, authors.url, authors.avatarURL, authors.emailAddress from authorsLookup lookup inner join authors on authors.authorID = lookup.authorID where lookup.articleID in \(placeholders);"
		let parameters = Array(articleIDs) as [Any]
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
			return [:]
		}

		var result: [String: Set<Author>] = [:]
		while resultSet.next() {
			guard let articleID = resultSet.swiftString(forColumn: DatabaseKey.articleID) else {
				continue
			}
			let authorID = resultSet.swiftString(forColumn: DatabaseKey.authorID)
			let name = resultSet.swiftString(forColumn: DatabaseKey.name)
			let url = resultSet.swiftString(forColumn: DatabaseKey.url)
			let avatarURL = resultSet.swiftString(forColumn: DatabaseKey.avatarURL)
			let emailAddress = resultSet.swiftString(forColumn: DatabaseKey.emailAddress)

			guard let author = Author(authorID: authorID, name: name, url: url, avatarURL: avatarURL, emailAddress: emailAddress) else {
				continue
			}
			result[articleID, default: Set<Author>()].insert(author)
		}
		resultSet.close()
		return result
	}
}
