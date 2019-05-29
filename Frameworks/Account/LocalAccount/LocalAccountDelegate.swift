//
//  LocalAccountDelegate.swift
//  Account
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
	
	let supportsSubFolders = false
	let usesTags = false
	let opmlImportInProgress = false
	
	let server: String? = nil
	var credentials: Credentials?
	var accountMetadata: AccountMetadata?

	private weak var account: Account?
	private var feedFinder: FeedFinder?
	private var createFeedName: String?
	private var createFeedContainer: Container?
	private var createFeedCompletion: ((Result<Feed, Error>) -> Void)?
	
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

		// We use the same mechanism to load local accounts as we do to load the subscription
		// OPML all accounts.
		BatchUpdate.shared.perform {
			account.loadOPML(loadDocument)
		}
		completion(.success(()))

	}

	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		folder.name = name
		completion(.success(()))
	}
	
	func deleteFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		account.deleteFolder(folder)
		completion(.success(()))
	}
	
	func createFeed(for account: Account, url urlString: String, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {
		
		guard let url = URL(string: urlString) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
	
		self.account = account
		createFeedName = name
		createFeedContainer =  container
		createFeedCompletion = completion
		feedFinder = FeedFinder(url: url, delegate: self)
		
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		feed.editedName = name
		completion(.success(()))
	}

	func deleteFeed(for account: Account, with feed: Feed, from container: Container?, completion: @escaping (Result<Void, Error>) -> Void) {
		if let account = container as? Account {
			account.removeFeed(feed)
		}
		if let folder = container as? Folder {
			folder.removeFeed(feed)
		}
		completion(.success(()))
	}
	
	func addFeed(for account: Account, to container: Container, with feed: Feed, completion: @escaping (Result<Void, Error>) -> Void) {
		if let folder = container as? Folder {
			folder.addFeed(feed)
		} else if let account = container as? Account {
			account.addFeed(feed)
		}
		completion(.success(()))
	}
	
	func removeFeed(for account: Account, from container: Container, with feed: Feed, completion: @escaping (Result<Void, Error>) -> Void) {
		if let account = container as? Account {
			account.removeFeed(feed)
		}
		if let folder = container as? Folder {
			folder.removeFeed(feed)
		}
		completion(.success(()))
	}
	
	func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.addFeed(feed, completion: completion)
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

	static func validateCredentials(transport: Transport, credentials: Credentials, completion: (Result<Bool, Error>) -> Void) {
		return completion(.success(false))
	}
	
}

extension LocalAccountDelegate: FeedFinderDelegate {
	
	// MARK: FeedFinderDelegate
	
	public func feedFinder(_ feedFinder: FeedFinder, didFindFeeds feedSpecifiers: Set<FeedSpecifier>) {
		
		if let error = feedFinder.initialDownloadError {
			if feedFinder.initialDownloadStatusCode == 404 {
				createFeedCompletion!(.failure(AccountError.createErrorNotFound))
			} else {
				createFeedCompletion!(.failure(error))
			}
			return
		}
		
		guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
			let url = URL(string: bestFeedSpecifier.urlString),
			let account = account else {
			createFeedCompletion!(.failure(AccountError.createErrorNotFound))
			return
		}

		if account.hasFeed(withURL: bestFeedSpecifier.urlString) {
			createFeedCompletion!(.failure(AccountError.createErrorAlreadySubscribed))
			return
		}
		
		let feed = account.createFeed(with: nil, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
		
		InitialFeedDownloader.download(url) { parsedFeed in
			
			if let parsedFeed = parsedFeed {
				account.update(feed, with: parsedFeed, {})
			}
			
			feed.editedName = self.createFeedName
			
			self.createFeedContainer?.addFeed(feed) { result in
				switch result {
				case .success:
					self.createFeedCompletion?(.success(feed))
				case .failure(let error):
					self.createFeedCompletion?(.failure(error))
				}
			}
			
		}

	}

}
