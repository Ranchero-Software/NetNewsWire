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

public enum LocalAccountDelegateError: String, Error {
	case invalidParameter = "An invalid parameter was used."
}

final class LocalAccountDelegate: AccountDelegate {

	weak var account: Account?
	
	lazy var refreshProgress: DownloadProgress = {
		refresher.downloadProgress
	}()

	let behaviors: AccountBehaviors = []
	let isOPMLImportInProgress = false
	
	let server: String? = nil
	var credentials: Credentials?
	var accountMetadata: AccountMetadata?

	private lazy var refresher: LocalAccountRefresher = {
		let refresher = LocalAccountRefresher()
		refresher.delegate = self
		return refresher
	}()

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		completion()
	}
	
	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		guard refreshProgress.isComplete, !Platform.isRunningUnitTests else {
			completion(.success(()))
			return
		}

		let webFeeds = account.flattenedWebFeeds()

		let group = DispatchGroup()

		group.enter()
		refresher.refreshFeeds(webFeeds) {
			group.leave()
		}
		
		group.notify(queue: DispatchQueue.main) {
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
	
	func createWebFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		guard let url = URL(string: urlString) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
        createRSSWebFeed(for: account, url: url, editedName: name, container: container, completion: completion)
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
	}
	
	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL? = nil, completion: (Result<Credentials?, Error>) -> Void) {
		return completion(.success(nil))
	}

	// MARK: Suspend and Resume (for iOS)

	func suspendNetwork() {
		refresher.suspend()
	}

	func suspendDatabase() {
		// Nothing to do
	}
	
	func resume() {
		refresher.resume()
	}
}

extension LocalAccountDelegate: LocalAccountRefresherDelegate {
		
	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges) {
	}
}

private extension LocalAccountDelegate {
	
	func createRSSWebFeed(for account: Account, url: URL, editedName: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> Void) {

		// We need to use a batch update here because we need to assign add the feed to the
		// container before the name has been downloaded.  This will put it in the sidebar
		// with an Untitled name if we don't delay it being added to the sidebar.
		BatchUpdate.shared.start()
		FeedFinder.find(url: url) { result in
			
			switch result {
			case .success(let feedSpecifiers):
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
					let url = URL(string: bestFeedSpecifier.urlString) else {
						BatchUpdate.shared.end()
						completion(.failure(AccountError.createErrorNotFound))
						return
				}
				
				if account.hasWebFeed(withURL: bestFeedSpecifier.urlString) {
					BatchUpdate.shared.end()
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}
				
				InitialFeedDownloader.download(url) { parsedFeed, _, response, _ in

					if let parsedFeed {
						let feed = account.createWebFeed(with: nil, url: url.absoluteString, webFeedID: url.absoluteString, homePageURL: nil)

						// Save conditional GET info so that first refresh uses conditional GET.
						if let httpResponse = response as? HTTPURLResponse,
						   let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse) {
							feed.conditionalGetInfo = conditionalGetInfo
						}
						
						feed.editedName = editedName
						container.addWebFeed(feed)

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
				completion(.failure(AccountError.createErrorNotFound))
			}
		}
	}
}
