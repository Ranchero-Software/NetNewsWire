//
//  ActivityManager.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 8/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import CoreSpotlight
import CoreServices
import Account
import Articles
import Intents

class ActivityManager {
	
	private var nextUnreadActivity: NSUserActivity?
	private var selectingActivity: NSUserActivity?
	private var readingActivity: NSUserActivity?

	var stateRestorationActivity: NSUserActivity? {
		if readingActivity != nil {
			return readingActivity
		}
		return selectingActivity
	}
	
	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .FeedIconDidBecomeAvailable, object: nil)
	}
	
	func invalidateCurrentActivities() {
		invalidateReading()
		invalidateSelecting()
		invalidateNextUnread()
	}
	
	func selectingToday() {
		invalidateCurrentActivities()
		
		let title = NSLocalizedString("See articles for “Today”", comment: "Today")
		selectingActivity = makeSelectingActivity(type: ActivityType.selectToday, title: title, identifier: "smartfeed.today")
		selectingActivity!.becomeCurrent()
	}
	
	func selectingAllUnread() {
		invalidateCurrentActivities()
		
		let title = NSLocalizedString("See articles in “All Unread”", comment: "All Unread")
		selectingActivity = makeSelectingActivity(type: ActivityType.selectAllUnread, title: title, identifier: "smartfeed.allUnread")
		selectingActivity!.becomeCurrent()
	}
	
	func selectingStarred() {
		invalidateCurrentActivities()
		
		let title = NSLocalizedString("See articles in “Starred”", comment: "Starred")
		selectingActivity = makeSelectingActivity(type: ActivityType.selectStarred, title: title, identifier: "smartfeed.starred")
		selectingActivity!.becomeCurrent()
	}
	
	func selectingFolder(_ folder: Folder) {
		invalidateCurrentActivities()
		
		let localizedText = NSLocalizedString("See articles in  “%@”", comment: "See articles in Folder")
		let title = NSString.localizedStringWithFormat(localizedText as NSString, folder.nameForDisplay) as String
		selectingActivity = makeSelectingActivity(type: ActivityType.selectFolder, title: title, identifier: ActivityManager.identifer(for: folder))
	 
		selectingActivity!.userInfo = [
			ActivityID.accountID.rawValue: folder.account?.accountID ?? "",
			ActivityID.accountName.rawValue: folder.account?.name ?? "",
			ActivityID.folderName.rawValue: folder.nameForDisplay
		]

		selectingActivity!.becomeCurrent()
	}
	
	func selectingFeed(_ feed: Feed) {
		invalidateCurrentActivities()
		
		let localizedText = NSLocalizedString("See articles in  “%@”", comment: "See articles in Feed")
		let title = NSString.localizedStringWithFormat(localizedText as NSString, feed.nameForDisplay) as String
		selectingActivity = makeSelectingActivity(type: ActivityType.selectFeed, title: title, identifier: ActivityManager.identifer(for: feed))
		
		selectingActivity!.userInfo = [
			ActivityID.accountID.rawValue: feed.account?.accountID ?? "",
			ActivityID.accountName.rawValue: feed.account?.name ?? "",
			ActivityID.feedID.rawValue: feed.feedID
		]
		updateSelectingActivityFeedSearchAttributes(with: feed)
		
		selectingActivity!.becomeCurrent()
	}
	
	func invalidateSelecting() {
		selectingActivity?.invalidate()
		selectingActivity = nil
	}
	
	func selectingNextUnread() {
		guard nextUnreadActivity == nil else { return }
		let title = NSLocalizedString("See first unread article", comment: "First Unread")
		nextUnreadActivity = makeSelectingActivity(type: ActivityType.nextUnread, title: title, identifier: "action.nextUnread")
		nextUnreadActivity!.becomeCurrent()
	}
	
	func invalidateNextUnread() {
		nextUnreadActivity?.invalidate()
		nextUnreadActivity = nil
	}
	
	func reading(_ article: Article?) {
		invalidateReading()
		invalidateNextUnread()
		guard let article = article else { return }
		readingActivity = makeReadArticleActivity(article)
		readingActivity?.becomeCurrent()
	}
	
	func invalidateReading() {
		readingActivity?.invalidate()
		readingActivity = nil
	}
	
	static func cleanUp(_ account: Account) {
		var ids = [String]()
		
		if let folders = account.folders {
			for folder in folders {
				ids.append(identifer(for: folder))
			}
		}
		
		for feed in account.flattenedFeeds() {
			ids.append(contentsOf: identifers(for: feed))
		}
		
		NSUserActivity.deleteSavedUserActivities(withPersistentIdentifiers: ids) {}
	}
	
	static func cleanUp(_ folder: Folder) {
		var ids = [String]()
		ids.append(identifer(for: folder))
		
		for feed in folder.flattenedFeeds() {
			ids.append(contentsOf: identifers(for: feed))
		}
		
		NSUserActivity.deleteSavedUserActivities(withPersistentIdentifiers: ids) {}
	}
	
	static func cleanUp(_ feed: Feed) {
		NSUserActivity.deleteSavedUserActivities(withPersistentIdentifiers: identifers(for: feed)) {}
	}
	
	@objc func feedIconDidBecomeAvailable(_ note: Notification) {
		guard let feed = note.userInfo?[UserInfoKey.feed] as? Feed, let activityFeedId = selectingActivity?.userInfo?[ActivityID.feedID.rawValue] as? String else {
			return
		}
		if activityFeedId == feed.feedID {
			updateSelectingActivityFeedSearchAttributes(with: feed)
		}
	}

}

// MARK: Private

private extension ActivityManager {
	
	func makeSelectingActivity(type: ActivityType, title: String, identifier: String) -> NSUserActivity {
		let activity = NSUserActivity(activityType: type.rawValue)
		activity.title = title
		activity.suggestedInvocationPhrase = title
		activity.keywords = Set(makeKeywords(title))
		activity.isEligibleForPrediction = true
		activity.isEligibleForSearch = true
		activity.persistentIdentifier = identifier
		return activity
	}
	
	func makeReadArticleActivity(_ article: Article) -> NSUserActivity {
		let activity = NSUserActivity(activityType: ActivityType.readArticle.rawValue)

		activity.title = article.title
		
		let feedNameKeywords = makeKeywords(article.feed?.nameForDisplay)
		let articleTitleKeywords = makeKeywords(article.title)
		let keywords = feedNameKeywords + articleTitleKeywords
		activity.keywords = Set(keywords)
		
		activity.userInfo = [
			ActivityID.accountID.rawValue: article.accountID,
			ActivityID.accountName.rawValue: article.account?.name ?? "",
			ActivityID.feedID.rawValue: article.feedID,
			ActivityID.articleID.rawValue: article.articleID
		]
		activity.isEligibleForSearch = true
		activity.isEligibleForPrediction = false
		activity.isEligibleForHandoff = true
		activity.persistentIdentifier = ActivityManager.identifer(for: article)
		
		// CoreSpotlight
		let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeCompositeContent as String)
		attributeSet.title = article.title
		attributeSet.contentDescription = article.summary
		attributeSet.keywords = keywords
		
		if let image = article.avatarImage() {
			attributeSet.thumbnailData = image.pngData()
		}
		
		activity.contentAttributeSet = attributeSet
		
		return activity
	}
	
	func makeKeywords(_ value: String?) -> [String] {
		return value?.components(separatedBy: " ").filter { $0.count > 2 } ?? []
	}
	
	func updateSelectingActivityFeedSearchAttributes(with feed: Feed) {
		
		let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
		attributeSet.title = feed.nameForDisplay
		attributeSet.keywords = makeKeywords(feed.nameForDisplay)
		if let image = appDelegate.feedIconDownloader.icon(for: feed) {
			attributeSet.thumbnailData = image.pngData()
		} else if let image = appDelegate.faviconDownloader.faviconAsAvatar(for: feed) {
			attributeSet.thumbnailData = image.pngData()
		}
		
		selectingActivity!.contentAttributeSet = attributeSet
		selectingActivity!.needsSave = true
		
	}
	
	static func identifer(for folder: Folder) -> String {
		return "account_\(folder.account!.accountID)_folder_\(folder.nameForDisplay)"
	}
	
	static func identifer(for feed: Feed) -> String {
		return "account_\(feed.account!.accountID)_feed_\(feed.feedID)"
	}
	
	static func identifer(for article: Article) -> String {
		return "account_\(article.accountID)_feed_\(article.feedID)_article_\(article.articleID)"
	}
	
	static func identifers(for feed: Feed) -> [String] {
		var ids = [String]()
		ids.append(identifer(for: feed))
		
		for article in feed.fetchArticles() {
			ids.append(identifer(for: article))
		}
		
		return ids
	}
	
}
