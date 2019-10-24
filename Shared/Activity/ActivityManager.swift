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
	private var readingArticle: Article?

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
		donate(selectingActivity!)
	}
	
	func selectingAllUnread() {
		invalidateCurrentActivities()
		
		let title = NSLocalizedString("See articles in “All Unread”", comment: "All Unread")
		selectingActivity = makeSelectingActivity(type: ActivityType.selectAllUnread, title: title, identifier: "smartfeed.allUnread")
		donate(selectingActivity!)
	}
	
	func selectingStarred() {
		invalidateCurrentActivities()
		
		let title = NSLocalizedString("See articles in “Starred”", comment: "Starred")
		selectingActivity = makeSelectingActivity(type: ActivityType.selectStarred, title: title, identifier: "smartfeed.starred")
		donate(selectingActivity!)
	}
	
	func selectingFolder(_ folder: Folder) {
		invalidateCurrentActivities()
		
		let localizedText = NSLocalizedString("See articles in  “%@”", comment: "See articles in Folder")
		let title = NSString.localizedStringWithFormat(localizedText as NSString, folder.nameForDisplay) as String
		selectingActivity = makeSelectingActivity(type: ActivityType.selectFolder, title: title, identifier: ActivityManager.identifer(for: folder))
	 
		let userInfo = folder.deepLinkUserInfo
		selectingActivity!.userInfo = userInfo
		selectingActivity!.requiredUserInfoKeys = Set(userInfo.keys.map { $0 as! String })
		donate(selectingActivity!)
	}
	
	func selectingFeed(_ feed: Feed) {
		invalidateCurrentActivities()
		
		let localizedText = NSLocalizedString("See articles in  “%@”", comment: "See articles in Feed")
		let title = NSString.localizedStringWithFormat(localizedText as NSString, feed.nameForDisplay) as String
		selectingActivity = makeSelectingActivity(type: ActivityType.selectFeed, title: title, identifier: ActivityManager.identifer(for: feed))
		
		let userInfo = feed.deepLinkUserInfo
		selectingActivity!.userInfo = userInfo
		selectingActivity!.requiredUserInfoKeys = Set(userInfo.keys.map { $0 as! String })
		updateSelectingActivityFeedSearchAttributes(with: feed)
		donate(selectingActivity!)
	}
	
	func invalidateSelecting() {
		selectingActivity?.invalidate()
		selectingActivity = nil
	}
	
	func selectingNextUnread() {
		guard nextUnreadActivity == nil else { return }
		let title = NSLocalizedString("See first unread article", comment: "First Unread")
		nextUnreadActivity = makeSelectingActivity(type: ActivityType.nextUnread, title: title, identifier: "action.nextUnread")
		donate(nextUnreadActivity!)
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
		
		#if os(iOS)
		updateReadArticleSearchAttributes(with: article)
		#endif
		
		donate(readingActivity!)
	}
	
	func invalidateReading() {
		readingActivity?.invalidate()
		readingActivity = nil
		readingArticle = nil
	}
	
	#if os(iOS)
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
		
		CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids)
	}
	
	static func cleanUp(_ folder: Folder) {
		var ids = [String]()
		ids.append(identifer(for: folder))
		
		for feed in folder.flattenedFeeds() {
			ids.append(contentsOf: identifers(for: feed))
		}
		
		CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids)
	}
	
	static func cleanUp(_ feed: Feed) {
		CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifers(for: feed))
	}
	#endif

	@objc func feedIconDidBecomeAvailable(_ note: Notification) {
		guard let feed = note.userInfo?[UserInfoKey.feed] as? Feed, let activityFeedId = selectingActivity?.userInfo?[DeepLinkKey.feedID.rawValue] as? String else {
			return
		}
		
		#if os(iOS)
		if let article = readingArticle, activityFeedId == article.feedID {
			updateReadArticleSearchAttributes(with: article)
		}
		#endif
		
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
		activity.keywords = Set(makeKeywords(title))
		activity.isEligibleForSearch = true

		#if os(iOS)
		activity.suggestedInvocationPhrase = title
		activity.isEligibleForPrediction = true
		activity.persistentIdentifier = identifier
		activity.contentAttributeSet?.relatedUniqueIdentifier = identifier
		#endif
		
		return activity
	}
	
	func makeReadArticleActivity(_ article: Article) -> NSUserActivity {
		let activity = NSUserActivity(activityType: ActivityType.readArticle.rawValue)
		activity.title = ArticleStringFormatter.truncatedTitle(article)
		let userInfo = article.deepLinkUserInfo
		activity.userInfo = userInfo
		activity.requiredUserInfoKeys = Set(userInfo.keys.map { $0 as! String })
		activity.isEligibleForHandoff = true
		
		#if os(iOS)
		activity.keywords = Set(makeKeywords(article))
		activity.isEligibleForSearch = true
		activity.isEligibleForPrediction = false
		activity.persistentIdentifier = ActivityManager.identifer(for: article)
		updateReadArticleSearchAttributes(with: article)
		#endif

		readingArticle = article
		
		return activity
	}
	
	#if os(iOS)
	func updateReadArticleSearchAttributes(with article: Article) {
		
		let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeCompositeContent as String)
		attributeSet.title = ArticleStringFormatter.truncatedTitle(article)
		attributeSet.contentDescription = article.summary
		attributeSet.keywords = makeKeywords(article)
		attributeSet.relatedUniqueIdentifier = ActivityManager.identifer(for: article)

		if let image = article.avatarImage() {
			attributeSet.thumbnailData = image.pngData()
		}
		
		readingActivity?.contentAttributeSet = attributeSet
		readingActivity?.needsSave = true
		
	}
	#endif
	
	func makeKeywords(_ article: Article) -> [String] {
		let feedNameKeywords = makeKeywords(article.feed?.nameForDisplay)
		let articleTitleKeywords = makeKeywords(ArticleStringFormatter.truncatedTitle(article))
		return feedNameKeywords + articleTitleKeywords
	}
	
	func makeKeywords(_ value: String?) -> [String] {
		return value?.components(separatedBy: " ").filter { $0.count > 2 } ?? []
	}
	
	func updateSelectingActivityFeedSearchAttributes(with feed: Feed) {
		
		let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
		attributeSet.title = feed.nameForDisplay
		attributeSet.keywords = makeKeywords(feed.nameForDisplay)
		attributeSet.relatedUniqueIdentifier = ActivityManager.identifer(for: feed)
		if let image = appDelegate.feedIconDownloader.icon(for: feed) {
			#if os(iOS)
			attributeSet.thumbnailData = image.pngData()
			#else
			attributeSet.thumbnailData = image.tiffRepresentation
			#endif
		} else if let image = appDelegate.faviconDownloader.faviconAsAvatar(for: feed) {
			#if os(iOS)
			attributeSet.thumbnailData = image.pngData()
			#else
			attributeSet.thumbnailData = image.tiffRepresentation
			#endif
		}
		
		selectingActivity!.contentAttributeSet = attributeSet
		selectingActivity!.needsSave = true
		
	}
	
	func donate(_ activity: NSUserActivity) {
		// You have to put the search item in the index or the activity won't index
		// itself because the relatedUniqueIdentifier on the activity attributeset is populated.
		if let attributeSet = activity.contentAttributeSet {
			let identifier = attributeSet.relatedUniqueIdentifier
			let tempAttributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
			let searchableItem = CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: nil, attributeSet: tempAttributeSet)
			CSSearchableIndex.default().indexSearchableItems([searchableItem])
		}
		
		activity.becomeCurrent()
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
