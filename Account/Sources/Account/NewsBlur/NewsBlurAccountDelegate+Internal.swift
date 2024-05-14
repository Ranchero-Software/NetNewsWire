//
//  NewsBlurAccountDelegate+Internal.swift
//  Mostly adapted from FeedbinAccountDelegate.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-14.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Articles
import Database
import Parser
import Web
import SyncDatabase
import os.log
import Core
import NewsBlur
import CommonErrors

extension NewsBlurAccountDelegate {
	
	func refreshFeeds(for account: Account) async throws {

		os_log(.debug, log: log, "Refreshing feeds…")

		let (feeds, folders) = try await caller.retrieveFeeds()

		BatchUpdate.shared.perform {
			self.syncFolders(account, folders)
			self.syncFeeds(account, feeds)
			self.syncFeedFolderRelationship(account, folders)
		}
	}

	func syncFolders(_ account: Account, _ folders: [NewsBlurFolder]?) {

		guard let folders else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing folders with %ld folders.", folders.count)

		let folderNames = folders.map { $0.name }

		// Delete any folders not at NewsBlur
		if let folders = account.folders {
			for folder in folders {
				if !folderNames.contains(folder.name ?? "") {
					for feed in folder.topLevelFeeds {
						account.addFeed(feed)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					}
					account.removeFolder(folder: folder)
				}
			}
		}

		let accountFolderNames: [String] =  {
			if let folders = account.folders {
				return folders.map { $0.name ?? "" }
			} else {
				return [String]()
			}
		}()

		// Make any folders NewsBlur has, but we don't
		// Ignore account-level folder
		for folderName in folderNames {
			if !accountFolderNames.contains(folderName) && folderName != " " {
				_ = account.ensureFolder(with: folderName)
			}
		}
	}

	func syncFeeds(_ account: Account, _ feeds: [NewsBlurFeed]?) {
		guard let feeds else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing feeds with %ld feeds.", feeds.count)

		let newsBlurFeedIDs = feeds.map { String($0.feedID) }

		// Remove any feeds that are no longer in the subscriptions
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !newsBlurFeedIDs.contains(feed.feedID) {
						folder.removeFeed(feed)
					}
				}
			}
		}

		for feed in account.topLevelFeeds {
			if !newsBlurFeedIDs.contains(feed.feedID) {
				account.removeFeed(feed)
			}
		}

		// Add any feeds we don't have and update any we do
		var feedsToAdd = Set<NewsBlurFeed>()
		feeds.forEach { feed in
			let subFeedID = String(feed.feedID)

			if let feed = account.existingFeed(withFeedID: subFeedID) {
				feed.name = feed.name
				// If the name has been changed on the server remove the locally edited name
				feed.editedName = nil
				feed.homePageURL = feed.homePageURL
				feed.externalID = String(feed.feedID)
				feed.faviconURL = feed.faviconURL
			}
			else {
				feedsToAdd.insert(feed)
			}
		}

		// Actually add feeds all in one go, so we don’t trigger various rebuilding things that Account does.
		for feed in feedsToAdd {
			let feed = account.createFeed(with: feed.name, url: feed.feedURL, feedID: String(feed.feedID), homePageURL: feed.homePageURL)
			feed.externalID = String(feed.feedID)
			account.addFeed(feed)
		}
	}

	func syncFeedFolderRelationship(_ account: Account, _ folders: [NewsBlurFolder]?) {

		guard let folders else { return }
		assert(Thread.isMainThread)

		os_log(.debug, log: log, "Syncing folders with %ld folders.", folders.count)

		// Set up some structures to make syncing easier
		let relationships = folders.map({ $0.asRelationships }).flatMap { $0 }
		let folderDict = nameToFolderDictionary(with: account.folders)
		let newsBlurFolderDict = relationships.reduce([String: [NewsBlurFolderRelationship]]()) { (dict, relationship) in
			var feedInFolders = dict
			if var feedInFolder = feedInFolders[relationship.folderName] {
				feedInFolder.append(relationship)
				feedInFolders[relationship.folderName] = feedInFolder
			} else {
				feedInFolders[relationship.folderName] = [relationship]
			}
			return feedInFolders
		}

		// Sync the folders
		for (folderName, folderRelationships) in newsBlurFolderDict {
			guard folderName != " " else {
				continue
			}

			let newsBlurFolderFeedIDs = folderRelationships.map { String($0.feedID) }

			guard let folder = folderDict[folderName] else { return }

			// Move any feeds not in the folder to the account
			for feed in folder.topLevelFeeds {
				if !newsBlurFolderFeedIDs.contains(feed.feedID) {
					folder.removeFeed(feed)
					clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					account.addFeed(feed)
				}
			}

			// Add any feeds not in the folder
			let folderFeedIDs = folder.topLevelFeeds.map { $0.feedID }

			for relationship in folderRelationships {
				let folderFeedID = String(relationship.feedID)
				if !folderFeedIDs.contains(folderFeedID) {
					guard let feed = account.existingFeed(withFeedID: folderFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, withFolderName: folderName, id: relationship.folderName)
					folder.addFeed(feed)
				}
			}
		}
		
		// Handle the account level feeds.  If there isn't the special folder, that means all the feeds are
		// in folders and we need to remove them all from the account level.
		if let folderRelationships = newsBlurFolderDict[" "] {
			let newsBlurFolderFeedIDs = folderRelationships.map { String($0.feedID) }
			for feed in account.topLevelFeeds {
				if !newsBlurFolderFeedIDs.contains(feed.feedID) {
					account.removeFeed(feed)
				}
			}
		} else {
			for feed in account.topLevelFeeds {
				account.removeFeed(feed)
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

	func nameToFolderDictionary(with folders: Set<Folder>?) -> [String: Folder] {
		guard let folders = folders else {
			return [String: Folder]()
		}

		var d = [String: Folder]()
		for folder in folders {
			let name = folder.name ?? ""
			if d[name] == nil {
				d[name] = folder
			}
		}
		return d
	}

	func refreshUnreadStories(for account: Account, hashes: [NewsBlurStoryHash]?, updateFetchDate: Date?) async throws {

		guard let hashes, !hashes.isEmpty else {
			if let lastArticleFetch = updateFetchDate {
				self.accountMetadata?.lastArticleFetchStartTime = lastArticleFetch
				self.accountMetadata?.lastArticleFetchEndTime = Date()
			}
			return
		}

		let numberOfStories = min(hashes.count, 100) // api limit
		let hashesToFetch = Array(hashes[..<numberOfStories])

		let (stories, date) = try await caller.retrieveStories(hashes: hashesToFetch)
		try await processStories(account: account, stories: stories)
		try await refreshUnreadStories(for: account, hashes: Array(hashes[numberOfStories...]), updateFetchDate: date)
		os_log(.debug, log: self.log, "Done refreshing stories.")
	}

	func mapStoriesToParsedItems(stories: [NewsBlurStory]?) -> Set<ParsedItem> {
		guard let stories = stories else { return Set<ParsedItem>() }

		let parsedItems: [ParsedItem] = stories.map { story in
			let author = Set([ParsedAuthor(name: story.authorName, url: nil, avatarURL: nil, emailAddress: nil)])
			return ParsedItem(syncServiceID: story.storyID, uniqueID: String(story.storyID), feedURL: String(story.feedID), url: story.url, externalURL: nil, title: story.title, language: nil, contentHTML: story.contentHTML, contentText: nil, summary: nil, imageURL: story.imageURL, bannerImageURL: nil, datePublished: story.datePublished, dateModified: nil, authors: author, tags: Set(story.tags ?? []), attachments: nil)
		}

		return Set(parsedItems)
	}

	func sendStoryStatuses(_ statuses: Set<SyncStatus>, throttle: Bool, apiCall: (Set<String>) async throws -> Void) async throws {

		guard !statuses.isEmpty else {
			return
		}

		var errorOccurred = false

		let storyHashes = statuses.compactMap { $0.articleID }
		let storyHashGroups = storyHashes.chunked(into: throttle ? 1 : 5) // api limit
		for storyHashGroup in storyHashGroups {

			do {
				try await apiCall(Set(storyHashGroup))
			} catch {
				errorOccurred = true
				os_log(.error, log: self.log, "Story status sync call failed: %@.", error.localizedDescription)
				try? await syncDatabase.resetSelectedForProcessing(storyHashGroup.map { String($0) } )
			}
		}

		if errorOccurred {
			throw NewsBlurError.unknown
		}
	}

	func syncStoryReadState(account: Account, hashes: Set<NewsBlurStoryHash>?) async {

		guard let hashes else {
			return
		}

		do {
			let pendingArticleIDs = (try await syncDatabase.selectPendingReadStatusArticleIDs()) ?? Set<String>()

			let newsBlurUnreadStoryHashes = Set(hashes.map { $0.hash } )
			let updatableNewsBlurUnreadStoryHashes = newsBlurUnreadStoryHashes.subtracting(pendingArticleIDs)

			guard let currentUnreadArticleIDs = try await account.fetchUnreadArticleIDs() else {
				return
			}

			// Mark articles as unread
			let deltaUnreadArticleIDs = updatableNewsBlurUnreadStoryHashes.subtracting(currentUnreadArticleIDs)
			try? await account.markAsUnread(deltaUnreadArticleIDs)

			// Mark articles as read
			let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableNewsBlurUnreadStoryHashes)
			try? await account.markAsRead(deltaReadArticleIDs)
		} catch {
			os_log(.error, log: self.log, "Sync Story Read Status failed: %@.", error.localizedDescription)
		}
	}

	func syncStoryStarredState(account: Account, hashes: Set<NewsBlurStoryHash>?) async {
		
		guard let hashes else {
			return
		}

		do {
			let pendingArticleIDs = (try await syncDatabase.selectPendingStarredStatusArticleIDs()) ?? Set<String>()

			let newsBlurStarredStoryHashes = Set(hashes.map { $0.hash } )
			let updatableNewsBlurUnreadStoryHashes = newsBlurStarredStoryHashes.subtracting(pendingArticleIDs)

			guard let currentStarredArticleIDs = try await account.fetchStarredArticleIDs() else {
				return
			}

			// Mark articles as starred
			let deltaStarredArticleIDs = updatableNewsBlurUnreadStoryHashes.subtracting(currentStarredArticleIDs)
			try? await account.markAsStarred(deltaStarredArticleIDs)

			// Mark articles as unstarred
			let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableNewsBlurUnreadStoryHashes)
			try? await account.markAsUnstarred(deltaUnstarredArticleIDs)
		} catch {
			os_log(.error, log: self.log, "Sync Story Starred Status failed: %@.", error.localizedDescription)
		}
	}

	func createFeed(account: Account, newsBlurFeed: NewsBlurFeed, name: String?, container: Container) async throws -> Feed {

		let feed = account.createFeed(with: newsBlurFeed.name, url: newsBlurFeed.feedURL, feedID: String(newsBlurFeed.feedID), homePageURL: newsBlurFeed.homePageURL)
		feed.externalID = String(newsBlurFeed.feedID)
		feed.faviconURL = newsBlurFeed.faviconURL

		try await account.addFeed(feed, to: container)
		if let name {
			try await renameFeed(for: account, with: feed, to: name)
		}
		try await initialFeedDownload(account: account, feed: feed)
		return feed
	}

	func downloadFeed(account: Account, feed: Feed, page: Int) async throws {

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		let (stories, _) = try await caller.retrieveStories(feedID: feed.feedID, page: page)
		refreshProgress.completeTask()

		guard let stories, stories.count > 0 else {
			return
		}

		let since: Date? = Calendar.current.date(byAdding: .month, value: -3, to: Date())

		let hasStories = try await processStories(account: account, stories: stories, since: since)
		if hasStories {
			try await downloadFeed(account: account, feed: feed, page: page + 1)
		}
	}

	func initialFeedDownload(account: Account, feed: Feed) async throws {

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		// Download the initial articles
		try await downloadFeed(account: account, feed: feed, page: 1)
		try await refreshArticleStatus(for: account)
		try await refreshMissingStories(for: account)
	}

	func deleteFeed(for account: Account, with feed: Feed, from container: Container?) async throws {

		// This error should never happen
		guard let feedID = feed.externalID else {
			throw NewsBlurError.invalidParameter
		}

		refreshProgress.addTask()
		defer {
			refreshProgress.completeTask()
		}

		let folderName = (container as? Folder)?.name

		do {
			try await caller.deleteFeed(feedID: feedID, folder: folderName)

			if folderName == nil {
				account.removeFeed(feed)
			}

			if let folders = account.folders {
				for folder in folders where folderName != nil && folder.name == folderName {
					folder.removeFeed(feed)
				}
			}

			if account.existingFeed(withFeedID: feed.feedID) != nil {
				account.clearFeedMetadata(feed)
			}

		} catch {
			throw AccountError.wrappedError(error: error, account: account)
		}
	}
}
