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
import RSCore
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
					self?.handleError(error)
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
		
		// After we successfully delete at Feedbin, we add all the feeds to the account to save them.  We then
		// delete the folder.  We then sync the taggings we received on the delete to remove any feeds from
		// the account that might be in another folder.
		caller.deleteTag(name: folder.name ?? "") { [weak self] result in
			switch result {
			case .success(let taggings):
				DispatchQueue.main.sync {
					BatchUpdate.shared.perform {
						for feed in folder.topLevelFeeds {
							account.addFeed(feed, to: nil)
							self?.clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
						}
						account.deleteFolder(folder)
					}
					completion(.success(()))
				}
				self?.syncTaggings(account, taggings)
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
				BatchUpdate.shared.perform {
					self?.syncFolders(account, tags)
				}
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
						for feed in folder.topLevelFeeds {
							account.addFeed(feed, to: nil)
							clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
						}
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
				
				self?.caller.retrieveTaggings { [weak self] result in
					switch result {
					case .success(let taggings):
						
						self?.caller.retrieveIcons { [weak self] result in
							switch result {
							case .success(let icons):

								BatchUpdate.shared.perform {
									self?.syncFeeds(account, subscriptions)
									self?.syncTaggings(account, taggings)
									self?.syncFavicons(account, icons)
								}

								completion(.success(()))
								
							case .failure(let error):
								completion(.failure(error))
							}
							
						}
						
					case .failure(let error):
						completion(.failure(error))
					}
					
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}

	func syncFeeds(_ account: Account, _ subscriptions: [FeedbinSubscription]?) {
		
		guard let subscriptions = subscriptions else { return }
		
		let subFeedIds = subscriptions.map { String($0.feedID) }
		
		// Remove any feeds that are no longer in the subscriptions
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !subFeedIds.contains(feed.feedID) {
						DispatchQueue.main.sync {
							folder.deleteFeed(feed)
						}
					}
				}
			}
		}
		
		for feed in account.topLevelFeeds {
			if !subFeedIds.contains(feed.feedID) {
				DispatchQueue.main.sync {
					account.deleteFeed(feed)
				}
			}
		}
		
		// Add any feeds we don't have and update any we do
		subscriptions.forEach { subscription in
			
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
		
	}

	func syncTaggings(_ account: Account, _ taggings: [FeedbinTagging]?) {
		
		guard let taggings = taggings else { return }

		// Set up some structures to make syncing easier
		let folderDict: [String: Folder] = {
			if let folders = account.folders {
				return Dictionary(uniqueKeysWithValues: folders.map { ($0.name ?? "", $0) } )
			} else {
				return [String: Folder]()
			}
		}()

		let taggingsDict = taggings.reduce([String: [FeedbinTagging]]()) { (dict, tagging) in
			var taggedFeeds = dict
			if var taggedFeed = taggedFeeds[tagging.name] {
				taggedFeed.append(tagging)
				taggedFeeds[tagging.name] = taggedFeed
			} else {
				taggedFeeds[tagging.name] = [tagging]
			}
			return taggedFeeds
		}

		// Sync the folders
		for (folderName, groupedTaggings) in taggingsDict {
			
			guard let folder = folderDict[folderName] else { return }
			
			let taggingFeedIDs = groupedTaggings.map { String($0.feedID) }
			
			// Move any feeds not in the folder to the account
			for feed in folder.topLevelFeeds {
				if !taggingFeedIDs.contains(feed.feedID) {
					DispatchQueue.main.sync {
						folder.deleteFeed(feed)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
						account.addFeed(feed, to: nil)
					}
				}
			}
			
			// Add any feeds not in the folder
			let folderFeedIds = folder.topLevelFeeds.map { $0.feedID }
			
			var feedsToAdd = Set<Feed>()
			for tagging in groupedTaggings {
				let taggingFeedID = String(tagging.feedID)
				if !folderFeedIds.contains(taggingFeedID) {
					guard let feed = account.idToFeedDictionary[taggingFeedID] else {
						continue
					}
					saveFolderRelationship(for: feed, withFolderName: folderName, id: String(tagging.taggingID))
					feedsToAdd.insert(feed)
				}
			}
			
			DispatchQueue.main.sync {
				folder.addFeeds(feedsToAdd)
			}
			
		}
		
		let taggedFeedIDs = Set(taggings.map { String($0.feedID) })
		
		// Delete all the feeds without a tag
		var feedsToDelete = Set<Feed>()
		for feed in account.topLevelFeeds {
			if taggedFeedIDs.contains(feed.feedID) {
				feedsToDelete.insert(feed)
			}
		}
		
		DispatchQueue.main.sync {
			account.deleteFeeds(feedsToDelete)
		}
		
	}
	
	func syncFavicons(_ account: Account, _ icons: [FeedbinIcon]?) {
		
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
	
	func clearFolderRelationship(for feed: Feed, withFolderName folderName: String) {
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderName] = nil
			feed.folderRelationship = folderRelationship
		}
	}
	
	func saveFolderRelationship(for feed: Feed, withFolderName folderName: String, id: String) {
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderName] = id
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderName: id]
		}
	}
	
}
