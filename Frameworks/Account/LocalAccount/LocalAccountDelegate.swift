//
//  LocalAccountDelegate.swift
//  Account
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

public enum LocalAccountDelegateError: String, Error {
	case invalidParameter = "An invalid parameter was used."
}

final class LocalAccountDelegate: AccountDelegate {
	
	let supportsSubFolders = false
	let server: String? = nil
	var credentials: Credentials?
	var accountMetadata: AccountMetadata?

	private weak var account: Account?
	private var feedFinder: FeedFinder?
	private var createFeedCompletion: ((Result<AccountCreateFeedResult, Error>) -> Void)?
	
	private let refresher = LocalAccountRefresher()

	var refreshProgress: DownloadProgress {
		return refresher.progress
	}
	
	// LocalAccountDelegate doesn't wait for completion before calling the completion block
	func refreshAll(for account: Account, completion: (() -> Void)? = nil) {
		refresher.refreshFeeds(account.flattenedFeeds())
		completion?()
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		folder.name = name
		completion(.success(()))
	}
	
	func deleteFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		account.deleteFolder(folder)
		completion(.success(()))
	}
	
	func createFeed(for account: Account, with name: String?, url urlString: String, completion: @escaping (Result<AccountCreateFeedResult, Error>) -> Void) {
		
		guard let url = URL(string: urlString) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
	
		self.account = account
		createFeedCompletion = completion
		
		feedFinder = FeedFinder(url: url, delegate: self)
		
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		feed.editedName = name
		completion(.success(()))
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
				createFeedCompletion!(.success(.notFound))
			} else {
				createFeedCompletion!(.failure(error))
			}
			return
		}
		
		guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
			let url = URL(string: bestFeedSpecifier.urlString),
			let account = account else {
			createFeedCompletion!(.success(.notFound))
			return
		}

		let feed = account.createFeed(with: nil, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
		InitialFeedDownloader.download(url) { [weak self] parsedFeed in
			if let parsedFeed = parsedFeed {
				account.update(feed, with: parsedFeed, {})
			}
			self?.createFeedCompletion!(.success(.created(feed)))
		}

	}

}
