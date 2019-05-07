//
//  FeedbinAccountDelegate.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
import RSCore
#endif
import RSWeb

final class FeedbinAccountDelegate: AccountDelegate {
	
	let supportsSubFolders = false
	let server: String? = "api.feedbin.com"
	
	private let caller: FeedbinAPICaller
	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}
	
	var accountMetadata: AccountMetadata? {
		didSet {
			caller.accountMetadata = accountMetadata
		}
	}

	init(transport: Transport) {
		caller = FeedbinAPICaller(transport: transport)
	}
	
	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	func refreshAll(for account: Account, completion: (() -> Void)? = nil) {
		refreshFolders(account) { [weak self] result in
			switch result {
			case .success():
				DispatchQueue.main.async {
					completion?()
				}
			case .failure(let error):
				DispatchQueue.main.async {
					completion?()
//					self?.handleError(error)
				}
			}
		}
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		
		caller.renameTag(oldName: folder.name ?? "", newName: name) { result in
			switch result {
			case .success:
				DispatchQueue.main.async {
					folder.name = name
					completion(.success(()))
				}
			case .failure(let error):
				DispatchQueue.main.async {
					completion(.failure(error))
				}
			}
		}
		
	}

	func deleteFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		
		// Feedbin uses tags and if at least one feed isn't tagged, then the folder doesn't exist on their system
		guard folder.hasAtLeastOneFeed() else {
			account.deleteFolder(folder)
			return
		}
		
		caller.deleteTag(name: folder.name ?? "") { result in
			switch result {
			case .success:
				DispatchQueue.main.async {

					account.deleteFolder(folder)
					// TODO: Take the serialized taggings and reestablish the folder to feed relationships.  Deleting
					// a tag on Feedbin doesn't any feeds.
					completion(.success(()))
				}
			case .failure(let error):
				DispatchQueue.main.async {
					completion(.failure(error))
				}
			}
		}
		
	}
	
	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveBasicCredentials()
		accountMetadata = account.metadata
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, completion: @escaping (Result<Bool, Error>) -> Void) {
		
		let caller = FeedbinAPICaller(transport: transport)
		caller.credentials = credentials
		caller.validateCredentials() { result in
			DispatchQueue.main.async {
				completion(result)
			}
		}
		
	}
	
}

// MARK: Private

private extension FeedbinAccountDelegate {
	
	func handleError(_ error: Error) {
		// TODO: We should do a better job of error handling here.
		// We need to prompt for credentials if they are expired.
		#if os(macOS)
		NSApplication.shared.presentError(error)
		#else
		UIApplication.shared.presentError(error)
		#endif
	}
	
	func refreshFolders(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		caller.retrieveTags { [weak self] result in
			switch result {
			case .success(let tags):
				self?.syncFolders(account, tags)
				self?.refreshFeeds(account, completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	func syncFolders(_ account: Account, _ tags: [FeedbinTag]?) {
		
		guard let tags = tags else { return }
		
		let tagNames = tags.map { $0.name }

		// Delete any folders not at Feedbin
		if let folders = account.folders {
			folders.forEach { folder in
				if !tagNames.contains(folder.name ?? "") {
					DispatchQueue.main.sync {
						account.deleteFolder(folder)
					}
				}
			}
		}
		
		let folderNames: [String] =  {
			if let folders = account.folders {
				return folders.map { $0.name ?? "" }
			} else {
				return [String]()
			}
		}()

		// Make any folders Feedbin has, but we don't
		tagNames.forEach { tagName in
			if !folderNames.contains(tagName) {
				DispatchQueue.main.sync {
					_ = account.ensureFolder(with: tagName)
				}
			}
		}
		
	}
	
	func refreshFeeds(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		caller.retrieveSubscriptions { [weak self] result in
			switch result {
			case .success(let subscriptions):
				self?.syncFeeds(account, subscriptions)
				self?.refreshFavicons(account, completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}

	func syncFeeds(_ account: Account, _ subscriptions: [FeedbinSubscription]?) {
		guard let subscriptions = subscriptions else { return }
		subscriptions.forEach { subscription in
			syncFeed(account, subscription)
		}
	}

	func syncFeed(_ account: Account, _ subscription: FeedbinSubscription) {
		
		let subFeedId = String(subscription.feedID)
		
		DispatchQueue.main.sync {
			if let feed = account.idToFeedDictionary[subFeedId] {
				feed.name = subscription.name
				feed.homePageURL = subscription.homePageURL
			} else {
				let feed = account.createFeed(with: subscription.name, editedName: nil, url: subscription.url, feedId: subFeedId, homePageURL: subscription.homePageURL)
				account.addFeed(feed, to: nil)
			}
		}

	}
	
	func refreshFavicons(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		caller.retrieveIcons { [weak self] result in
			switch result {
			case .success(let icons):
				self?.syncIcons(account, icons)
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	func syncIcons(_ account: Account, _ icons: [FeedbinIcon]?) {
		
		guard let icons = icons else { return }
		
		let iconDict = Dictionary(uniqueKeysWithValues: icons.map { ($0.host, $0.url) } )
		
		for feed in account.flattenedFeeds() {
			for (key, value) in iconDict {
				if feed.homePageURL?.contains(key) ?? false {
					DispatchQueue.main.sync {
						feed.faviconURL = value
					}
					break
				}
			}
		}

	}
	
}
