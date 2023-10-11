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
import ArticlesDatabase
import RSWeb
import Secrets
import AccountError
import FeedFinder
import LocalAccount

public enum LocalAccountDelegateError: String, Error {
	case invalidParameter = "An invalid parameter was used."
}

final class LocalAccountDelegate: AccountDelegate, Logging {

	weak var account: Account?
	
	private lazy var refresher: LocalAccountRefresher? = {
		let refresher = LocalAccountRefresher()
		refresher.delegate = self
		return refresher
	}()
	
	let behaviors: AccountBehaviors = []
	let isOPMLImportInProgress = false
	
	let server: String? = nil
	var credentials: Credentials?
	var accountMetadata: AccountMetadata?

	let refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
		return
	}

    func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
        guard refreshProgress.isComplete else {
            completion(.success(()))
            return
        }

        let feeds = account.flattenedFeeds()
		let feedURLs = Set(feeds.map{ $0.url })
        refreshProgress.addToNumberOfTasksAndRemaining(feedURLs.count)

        let group = DispatchGroup()

        group.enter()
        refresher?.refreshFeedURLs(feedURLs) {
            group.leave()
        }

        group.notify(queue: DispatchQueue.main) {
            self.refreshProgress.clear()
            account.metadata.lastArticleFetchEndTime = Date()
            completion(.success(()))
        }
    }


	func syncArticleStatus(for account: Account, completion: ((Result<Void, Error>) -> Void)? = nil) {
		completion?(.success(()))
	}
	
	func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		completion(.success(()))
	}
	
	func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		completion(.success(()))
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
			account.loadOPMLItems(children)
		}
		
		completion(.success(()))

	}
	
	func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {
		guard let url = URL(string: urlString) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
		// Username should be part of the URL on new feed adds
		createRSSFeed(for: account, url: url, editedName: name, container: container, completion: completion)
	}

    func renameFeed(for account: Account, feed: Feed, name: String) async throws {
        feed.editedName = name
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
	
	func createFolder(for account: Account, name: String) async throws -> Folder {
		try await withCheckedThrowingContinuation { continuation in
			if let folder = account.ensureFolder(with: name) {
				continuation.resume(returning: folder)
			} else {
				continuation.resume(throwing: FeedbinAccountDelegateError.invalidParameter)
			}
		}
	}
	
	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		folder.name = name
	}
	
	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		account.removeFolder(folder)
		completion(.success(()))
	}
	
	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		account.addFolder(folder)
		completion(.success(()))
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		account.update(articles, statusKey: statusKey, flag: flag) { result in
			if case .failure(let error) = result {
				completion(.failure(error))
			} else {
				completion(.success(()))
			}
		}
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account
		refreshProgress.name = account.nameForDisplay
		refreshProgress.isPrecise = true
	}
	
	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL? = nil) async throws -> Credentials? {
		nil
	}

	// MARK: Suspend and Resume (for iOS)

	func suspendNetwork() {
		refresher?.suspend()
	}

	func suspendDatabase() {
		// Nothing to do
	}
	
	func resume() {
		refresher?.resume()
	}
}

extension LocalAccountDelegate: LocalAccountRefresherDelegate {

	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestForFeedURL feedURL: String) -> URLRequest? {

		guard let url = URL(string: feedURL) else {
			return nil
		}

		var request = URLRequest(url: url)
		if let feed = account?.existingFeed(withURL: feedURL) {
			feed.conditionalGetInfo?.addRequestHeadersToURLRequest(&request)
		}

		return request
	}

	func localAccountRefresher(_ refresher: LocalAccountRefresher, feedURL: String, response: URLResponse?, data: Data, error: Error?, completion: @escaping () -> Void) {

		guard !data.isEmpty else {
			completion()
			return
		}

		if let error = error {
			print("Error downloading \(feedURL) - \(error)")
			completion()
			return
		}

		guard let feed = account?.existingFeed(withURL: feedURL) else {
			completion()
			return
		}

		processFeed(feed, response, data, completion)
	}
	
	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedForFeedURL: String) {
		refreshProgress.completeTask()
	}
}

private extension LocalAccountDelegate {
	
	func createRSSFeed(for account: Account, url: URL, editedName: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {

		// We need to use a batch update here because we need to assign add the feed to the
		// container before the name has been downloaded.  This will put it in the sidebar
		// with an Untitled name if we don't delay it being added to the sidebar.
		BatchUpdate.shared.start()
		refreshProgress.addToNumberOfTasksAndRemaining(1)

		Task { @MainActor in

			do {
				let feedSpecifiers = try await FeedFinder.find(url: url)
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
					  let url = URL(string: bestFeedSpecifier.urlString) else {
					self.refreshProgress.completeTask()
					BatchUpdate.shared.end()
					completion(.failure(AccountError.createErrorNotFound))
					return
				}

				if account.hasFeed(withURL: bestFeedSpecifier.urlString) {
					self.refreshProgress.completeTask()
					BatchUpdate.shared.end()
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}

				InitialFeedDownloader.download(url) { parsedFeed in
					self.refreshProgress.completeTask()

					if let parsedFeed = parsedFeed {
						let feed = account.createFeed(with: nil, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
						feed.editedName = editedName
						container.addFeed(feed)

						account.update(feed, with: parsedFeed, {_ in
							BatchUpdate.shared.end()
							completion(.success(feed))
						})
					} else {
						BatchUpdate.shared.end()
						completion(.failure(AccountError.createErrorNotFound))
					}

				}
			} catch {
				BatchUpdate.shared.end()
				self.refreshProgress.completeTask()
				completion(.failure(AccountError.createErrorNotFound))
			}
		}
	}

	func processFeed(_ feed: Feed, _ response: URLResponse?, _ data: Data, _ completion: @escaping () -> Void) {

		let dataHash = data.md5String
		if dataHash == feed.contentHash {
			completion()
			return
		}

		let parserData = ParserData(url: feed.url, data: data)
		FeedParser.parse(parserData) { (parsedFeed, error) in

			Task { @MainActor in
				guard let account = self.account, let parsedFeed = parsedFeed, error == nil else {
					completion()
					return
				}

				account.update(feed, with: parsedFeed) { result in
					if case .success(_) = result {
						if let httpResponse = response as? HTTPURLResponse {
							feed.conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
						}
						feed.contentHash = dataHash
					}
					completion()
				}
			}
		}
	}
}
