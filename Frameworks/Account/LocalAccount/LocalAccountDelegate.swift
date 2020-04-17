//
//  LocalAccountDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore
import RSParser
import Articles
import ArticlesDatabase
import RSWeb
import Secrets

public enum LocalAccountDelegateError: String, Error {
	case invalidParameter = "An invalid parameter was used."
}

final class LocalAccountDelegate: AccountDelegate {

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "LocalAccount")

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
	
	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		completion()
	}
	
	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		guard refreshProgress.isComplete else {
			completion(.success(()))
			return
		}

		var refresherWebFeeds = Set<WebFeed>()
		let webFeeds = account.flattenedWebFeeds()
		
		let group = DispatchGroup()
		
		for webFeed in webFeeds {
			if let components = URLComponents(string: webFeed.url), let feedProvider = FeedProviderManager.shared.best(for: components, with: webFeed.username) {
				refreshProgress.addToNumberOfTasksAndRemaining(1)
				group.enter()
				feedProvider.refresh(webFeed) { result in
					switch result {
					case .success(let parsedItems):
						account.update(webFeed.webFeedID, with: parsedItems) { _ in
							self.refreshProgress.completeTask()
							group.leave()
						}
					case .failure(let error):
						os_log(.error, log: self.log, "Feed Provider refresh error: %@.", error.localizedDescription)
						self.refreshProgress.completeTask()
						group.leave()
					}
				}
			} else {
				refresherWebFeeds.insert(webFeed)
			}
		}
		
		refreshProgress.addToNumberOfTasksAndRemaining(refresherWebFeeds.count)
		group.enter()
		refresher?.refreshFeeds(refresherWebFeeds) {
			group.leave()
		}
		
		group.notify(queue: DispatchQueue.main) {
			completion(.success(()))
		}
		
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
	
	func createWebFeed(for account: Account, url urlString: String, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		guard let url = URL(string: urlString), let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
		// Username should be part of the URL on new feed adds
		if let feedProvider = FeedProviderManager.shared.best(for: urlComponents, with: nil) {
			createProviderWebFeed(for: account, urlComponents: urlComponents, name: name, container: container, feedProvider: feedProvider, completion: completion)
		} else {
			createRSSWebFeed(for: account, url: url, name: name, container: container, completion: completion)
		}
	}

	func renameWebFeed(for account: Account, with feed: WebFeed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		feed.editedName = name
		completion(.success(()))
	}

	func removeWebFeed(for account: Account, with feed: WebFeed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.removeWebFeed(feed)
		completion(.success(()))
	}
	
	func moveWebFeed(for account: Account, with feed: WebFeed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		from.removeWebFeed(feed)
		to.addWebFeed(feed)
		completion(.success(()))
	}
	
	func addWebFeed(for account: Account, with feed: WebFeed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.addWebFeed(feed)
		completion(.success(()))
	}
	
	func restoreWebFeed(for account: Account, feed: WebFeed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.addWebFeed(feed)
		completion(.success(()))
	}
	
	func createFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
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
		return try? account.update(articles, statusKey: statusKey, flag: flag)
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account
	}
	
	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL? = nil, completion: (Result<Credentials?, Error>) -> Void) {
		return completion(.success(nil))
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

	func localAccountRefresher(_ refresher: LocalAccountRefresher, didProcess newAndUpdatedArticles: NewAndUpdatedArticles, completion: @escaping () -> Void) {
		completion()
	}
	
	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedFor: WebFeed) {
		refreshProgress.completeTask()
	}
	
	func localAccountRefresherDidFinish(_ refresher: LocalAccountRefresher) {
		self.refreshProgress.clear()
		account?.metadata.lastArticleFetchEndTime = Date()
	}
	
}

private extension LocalAccountDelegate {
	
	func createProviderWebFeed(for account: Account, urlComponents: URLComponents, name: String?, container: Container, feedProvider: FeedProvider, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		refreshProgress.addToNumberOfTasksAndRemaining(2)
		
		feedProvider.assignName(urlComponents) { result in
			self.refreshProgress.completeTask()
			switch result {
				
			case .success(let name):

				// Move the user to the WebFeed and out of the URL
				var newURLComponents = urlComponents
				newURLComponents.user = nil
				guard let newURLString = newURLComponents.url?.absoluteString else {
					completion(.failure(AccountError.createErrorNotFound))
					return
				}

				let feed = account.createWebFeed(with: name, url: newURLString, webFeedID: newURLString, homePageURL: nil)
				feed.editedName = name
				feed.username = urlComponents.user
				container.addWebFeed(feed)

				feedProvider.refresh(feed) { result in
					self.refreshProgress.completeTask()
					switch result {
					case .success(let parsedItems):
						account.update(newURLString, with: parsedItems) { _ in
							completion(.success(feed))
						}
					case .failure:
						completion(.failure(AccountError.createErrorNotFound))
					}
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func createRSSWebFeed(for account: Account, url: URL, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		
		refreshProgress.addToNumberOfTasksAndRemaining(1)
		BatchUpdate.shared.start()
		FeedFinder.find(url: url) { result in
			
			switch result {
			case .success(let feedSpecifiers):
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
					let url = URL(string: bestFeedSpecifier.urlString) else {
						self.refreshProgress.completeTask()
						BatchUpdate.shared.end()
						completion(.failure(AccountError.createErrorNotFound))
						return
				}
				
				if account.hasWebFeed(withURL: bestFeedSpecifier.urlString) {
					self.refreshProgress.completeTask()
					BatchUpdate.shared.end()
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}
				
				let feed = account.createWebFeed(with: nil, url: url.absoluteString, webFeedID: url.absoluteString, homePageURL: nil)
				feed.editedName = name
				container.addWebFeed(feed)

				InitialFeedDownloader.download(url) { parsedFeed in
					self.refreshProgress.completeTask()

					if let parsedFeed = parsedFeed {
						account.update(feed, with: parsedFeed, {_ in
							BatchUpdate.shared.end()
							completion(.success(feed))
						})
					} else {
						BatchUpdate.shared.end()
						completion(.failure(AccountError.createErrorNotFound))
					}
					
				}
				
			case .failure:
				BatchUpdate.shared.end()
				self.refreshProgress.completeTask()
				completion(.failure(AccountError.createErrorNotFound))
			}
			
		}
		
	}
	
}
