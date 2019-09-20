//
//  LocalAccountDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser
import Articles
import RSWeb

public enum LocalAccountDelegateError: String, Error {
	case invalidParameter = "An invalid parameter was used."
}

final class LocalAccountDelegate: AccountDelegate {
	
	let behaviors: AccountBehaviors = []
	let isOPMLImportInProgress = false
	
	let server: String? = nil
	var credentials: Credentials?
	var accountMetadata: AccountMetadata?

	private let refresher = LocalAccountRefresher()

	var refreshProgress: DownloadProgress {
		return refresher.progress
	}
	
	// LocalAccountDelegate doesn't wait for completion before calling the completion block
	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		refresher.refreshFeeds(account.flattenedFeeds())
		completion(.success(()))
	}

	func sendArticleStatus(for account: Account, completion: @escaping (() -> Void)) {
		completion()
	}
	
	func refreshArticleStatus(for account: Account, completion: @escaping (() -> Void)) {
		completion()
	}
	
	func importOPML(for account:Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
		var fileData: Data?
		
		do {
			fileData = try Data(contentsOf: opmlFile)
		} catch {
			completion(.failure(error))
			return
		}
		
		guard let opmlData = fileData else {
			completion(.success(()))
			return
		}
		
		let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
		var opmlDocument: RSOPMLDocument?
		
		do {
			opmlDocument = try RSOPMLParser.parseOPML(with: parserData)
		} catch {
			completion(.failure(error))
			return
		}
		
		guard let loadDocument = opmlDocument else {
			completion(.success(()))
			return
		}

		guard let children = loadDocument.children else {
			return
		}

		BatchUpdate.shared.perform {
			account.loadOPMLItems(children, parentFolder: nil)
		}
		
		completion(.success(()))

	}
	
	func createFeed(for account: Account, url urlString: String, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {
		guard let url = URL(string: urlString) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		FeedFinder.find(url: url) { result in
			
			switch result {
			case .success(let feedSpecifiers):
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
					let url = URL(string: bestFeedSpecifier.urlString) else {
						self.refreshProgress.completeTask()
						completion(.failure(AccountError.createErrorNotFound))
						return
				}
				
				if account.hasFeed(withURL: bestFeedSpecifier.urlString) {
					self.refreshProgress.completeTask()
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}
				
				let feed = account.createFeed(with: nil, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
				
				InitialFeedDownloader.download(url) { parsedFeed in
					self.refreshProgress.completeTask()

					if let parsedFeed = parsedFeed {
						account.update(feed, with: parsedFeed, {})
					}
					
					feed.editedName = name
					
					container.addFeed(feed)
					completion(.success(feed))
					
				}
				
			case .failure:
				self.refreshProgress.completeTask()
				completion(.failure(AccountError.createErrorNotFound))
			}
			
		}

	}

	func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		feed.editedName = name
		completion(.success(()))
	}

	func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.removeFeed(feed)
		completion(.success(()))
	}
	
	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		from.removeFeed(feed)
		to.addFeed(feed)
		completion(.success(()))
	}
	
	func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.addFeed(feed)
		completion(.success(()))
	}
	
	func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.addFeed(feed)
		completion(.success(()))
	}
	
	func addFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		if let folder = account.ensureFolder(with: name) {
			completion(.success(folder))
		} else {
			completion(.failure(FeedbinAccountDelegateError.invalidParameter))
		}
	}
	
	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		folder.name = name
		completion(.success(()))
	}
	
	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		account.removeFolder(folder)
		completion(.success(()))
	}
	
	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		account.addFolder(folder)
		completion(.success(()))
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<Article>? {
		return account.update(articles, statusKey: statusKey, flag: flag)
	}

	func accountDidInitialize(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL? = nil, completion: (Result<Credentials?, Error>) -> Void) {
		return completion(.success(nil))
	}
}
