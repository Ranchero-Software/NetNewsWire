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
import RSCore
import Account
import Articles
import Intents
import UniformTypeIdentifiers

final class ActivityManager {
	
	private var nextUnreadActivity: NSUserActivity?
	private var selectingActivity: NSUserActivity?
	private var readingActivity: NSUserActivity?
	private var readingArticle: Article?

	var stateRestorationActivity: NSUserActivity {
		if let activity = readingActivity {
			return activity
		}
		
		if let activity = selectingActivity {
			return activity
		}
		
		let activity = NSUserActivity(activityType: ActivityType.restoration.rawValue)
		#if os(iOS)
		activity.persistentIdentifier = UUID().uuidString
		#endif
		activity.becomeCurrent()
		return activity
	}
	
	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .feedIconDidBecomeAvailable, object: nil)
	}
	
	func invalidateCurrentActivities() {
		invalidateReading()
		invalidateSelecting()
		invalidateNextUnread()
	}
	
	func selecting(sidebarItem: SidebarItem) {
		invalidateCurrentActivities()
		
		selectingActivity = makeSelectFeedActivity(sidebarItem: sidebarItem)
		
		if let webFeed = sidebarItem as? Feed {
			updateSelectingActivityFeedSearchAttributes(with: webFeed)
		}
		
		donate(selectingActivity!)
	}
	
	func invalidateSelecting() {
		selectingActivity?.invalidate()
		selectingActivity = nil
	}
	
	func selectingNextUnread() {
		guard nextUnreadActivity == nil else { return }

		nextUnreadActivity = NSUserActivity(activityType: ActivityType.nextUnread.rawValue)
		nextUnreadActivity!.title = NSLocalizedString("See first unread article", comment: "First Unread")
		
		#if os(iOS)
		nextUnreadActivity!.suggestedInvocationPhrase = nextUnreadActivity!.title
		nextUnreadActivity!.isEligibleForPrediction = true
		nextUnreadActivity!.persistentIdentifier = "nextUnread:"
		nextUnreadActivity!.contentAttributeSet?.relatedUniqueIdentifier = "nextUnread:"
		#endif

		donate(nextUnreadActivity!)
	}
	
	func invalidateNextUnread() {
		nextUnreadActivity?.invalidate()
		nextUnreadActivity = nil
	}
	
	func reading(feed: SidebarItem?, article: Article?) {
		invalidateReading()
		invalidateNextUnread()
		
		guard let article = article else { return }
		readingActivity = makeReadArticleActivity(sidebarItem: feed, article: article)
		
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
				ids.append(identifier(for: folder))
			}
		}
		
		for webFeed in account.flattenedWebFeeds() {
			ids.append(contentsOf: identifiers(for: webFeed))
		}
		
		CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids)
	}
	
	static func cleanUp(_ folder: Folder) {
		var ids = [String]()
		ids.append(identifier(for: folder))
		
		for webFeed in folder.flattenedWebFeeds() {
			ids.append(contentsOf: identifiers(for: webFeed))
		}
		
		CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids)
	}
	
	static func cleanUp(_ webFeed: Feed) {
		CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers(for: webFeed))
	}
	#endif

	@objc func webFeedIconDidBecomeAvailable(_ note: Notification) {
		guard let webFeed = note.userInfo?[UserInfoKey.webFeed] as? Feed, let activityFeedId = selectingActivity?.userInfo?[ArticlePathKey.webFeedID] as? String else {
			return
		}
		
		#if os(iOS)
		if let article = readingArticle, activityFeedId == article.webFeedID {
			updateReadArticleSearchAttributes(with: article)
		}
		#endif
		
		if activityFeedId == webFeed.webFeedID {
			updateSelectingActivityFeedSearchAttributes(with: webFeed)
		}
	}

}

// MARK: Private

private extension ActivityManager {
	
	func makeSelectFeedActivity(sidebarItem: SidebarItem) -> NSUserActivity {
		let activity = NSUserActivity(activityType: ActivityType.selectFeed.rawValue)
		
		let localizedText = NSLocalizedString("See articles in  “%@”", comment: "See articles in Folder")
		let title = NSString.localizedStringWithFormat(localizedText as NSString, sidebarItem.nameForDisplay) as String
		activity.title = title
		
		activity.keywords = Set(makeKeywords(title))
		activity.isEligibleForSearch = true
		
		let articleFetcherIdentifierUserInfo = sidebarItem.sidebarItemID?.userInfo ?? [AnyHashable: Any]()
		activity.userInfo = [UserInfoKey.feedIdentifier: articleFetcherIdentifierUserInfo]
		activity.requiredUserInfoKeys = Set(activity.userInfo!.keys.map { $0 as! String })

		activity.persistentIdentifier = sidebarItem.sidebarItemID?.description ?? ""

		#if os(iOS)
		activity.suggestedInvocationPhrase = title
		activity.isEligibleForPrediction = true
		activity.contentAttributeSet?.relatedUniqueIdentifier = sidebarItem.sidebarItemID?.description ?? ""
		#endif

		return activity
	}
	
	func makeReadArticleActivity(sidebarItem: SidebarItem?, article: Article) -> NSUserActivity {
		let activity = NSUserActivity(activityType: ActivityType.readArticle.rawValue)
		activity.title = ArticleStringFormatter.truncatedTitle(article)
		
		if let sidebarItem {
			let articleFetcherIdentifierUserInfo = sidebarItem.sidebarItemID?.userInfo ?? [AnyHashable: Any]()
			let articlePathUserInfo = article.pathUserInfo
			activity.userInfo = [UserInfoKey.feedIdentifier: articleFetcherIdentifierUserInfo, UserInfoKey.articlePath: articlePathUserInfo]
		} else {
			activity.userInfo = [UserInfoKey.articlePath: article.pathUserInfo]
		}
		activity.requiredUserInfoKeys = Set(activity.userInfo!.keys.map { $0 as! String })
		
		activity.isEligibleForHandoff = true
		
		activity.persistentIdentifier = ActivityManager.identifier(for: article)

		#if os(iOS)
		activity.keywords = Set(makeKeywords(article))
		activity.isEligibleForSearch = true
		activity.isEligibleForPrediction = false
		updateReadArticleSearchAttributes(with: article)
		#endif

		readingArticle = article
		
		return activity
	}
	
	#if os(iOS)
	func updateReadArticleSearchAttributes(with article: Article) {
		
		let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.compositeContent.identifier)
		attributeSet.title = ArticleStringFormatter.truncatedTitle(article)
		attributeSet.contentDescription = article.summary
		attributeSet.keywords = makeKeywords(article)
		attributeSet.relatedUniqueIdentifier = ActivityManager.identifier(for: article)

		if let iconImage = article.iconImage() {
			attributeSet.thumbnailData = iconImage.image.pngData()
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
		
		let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.compositeContent)
		attributeSet.title = feed.nameForDisplay
		attributeSet.keywords = makeKeywords(feed.nameForDisplay)
		attributeSet.relatedUniqueIdentifier = ActivityManager.identifier(for: feed)

		if let iconImage = IconImageCache.shared.imageForFeed(feed) {
			attributeSet.thumbnailData = iconImage.image.dataRepresentation()
		}

		selectingActivity!.contentAttributeSet = attributeSet
		selectingActivity!.needsSave = true
		
	}
	
	func donate(_ activity: NSUserActivity) {
		// You have to put the search item in the index or the activity won't index
		// itself because the relatedUniqueIdentifier on the activity attributeset is populated.
		if let attributeSet = activity.contentAttributeSet {
			let identifier = attributeSet.relatedUniqueIdentifier
			let tempAttributeSet = CSSearchableItemAttributeSet(contentType: UTType.item)
			let searchableItem = CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: nil, attributeSet: tempAttributeSet)
			CSSearchableIndex.default().indexSearchableItems([searchableItem])
		}
		
		activity.becomeCurrent()
	}
	
	static func identifier(for folder: Folder) -> String {
		return "account_\(folder.account!.accountID)_folder_\(folder.nameForDisplay)"
	}
	
	static func identifier(for feed: Feed) -> String {
		return "account_\(feed.account!.accountID)_feed_\(feed.webFeedID)"
	}
	
	static func identifier(for article: Article) -> String {
		return "account_\(article.accountID)_feed_\(article.webFeedID)_article_\(article.articleID)"
	}
	
	static func identifiers(for feed: Feed) -> [String] {
		var ids = [String]()
		ids.append(identifier(for: feed))
		if let articles = try? feed.fetchArticles() {
			for article in articles {
				ids.append(identifier(for: article))
			}
		}

		return ids
	}
}
