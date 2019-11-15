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
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
	}
	
	func invalidateCurrentActivities() {
		invalidateReading()
		invalidateSelecting()
		invalidateNextUnread()
	}
	
	func selecting(fetcher: ArticleFetcher) {
		invalidateCurrentActivities()
		
		selectingActivity = makeSelectFeedActivity(fetcher: fetcher)
		
		if let feed = fetcher as? WebFeed {
			updateSelectingActivityFeedSearchAttributes(with: feed)
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
	
	func reading(fetcher: ArticleFetcher?, article: Article?) {
		invalidateReading()
		invalidateNextUnread()
		
		guard let article = article else { return }
		readingActivity = makeReadArticleActivity(fetcher: fetcher, article: article)
		
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
		
		for webFeed in account.flattenedWebFeeds() {
			ids.append(contentsOf: identifers(for: webFeed))
		}
		
		CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids)
	}
	
	static func cleanUp(_ folder: Folder) {
		var ids = [String]()
		ids.append(identifer(for: folder))
		
		for webFeed in folder.flattenedWebFeeds() {
			ids.append(contentsOf: identifers(for: webFeed))
		}
		
		CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids)
	}
	
	static func cleanUp(_ webFeed: WebFeed) {
		CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifers(for: webFeed))
	}
	#endif

	@objc func webFeedIconDidBecomeAvailable(_ note: Notification) {
		guard let webFeed = note.userInfo?[UserInfoKey.webFeed] as? WebFeed, let activityFeedId = selectingActivity?.userInfo?[ArticlePathKey.webFeedID] as? String else {
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
	
	func makeSelectFeedActivity(fetcher: ArticleFetcher) -> NSUserActivity {
		let activity = NSUserActivity(activityType: ActivityType.selectFeed.rawValue)
		
		let localizedText = NSLocalizedString("See articles in  “%@”", comment: "See articles in Folder")
		let displayName = (fetcher as? DisplayNameProvider)?.nameForDisplay ?? ""
		let title = NSString.localizedStringWithFormat(localizedText as NSString, displayName) as String
		activity.title = title
		
		activity.keywords = Set(makeKeywords(title))
		activity.isEligibleForSearch = true
		
		let articleFetcherIdentifierUserInfo = fetcher.articleFetcherType?.userInfo ?? [AnyHashable: Any]()
		activity.userInfo = [UserInfoKey.feedIdentifier: articleFetcherIdentifierUserInfo]
		activity.requiredUserInfoKeys = Set(activity.userInfo!.keys.map { $0 as! String })

		#if os(iOS)
		activity.suggestedInvocationPhrase = title
		activity.isEligibleForPrediction = true
		activity.persistentIdentifier = fetcher.articleFetcherType?.description ?? ""
		activity.contentAttributeSet?.relatedUniqueIdentifier = fetcher.articleFetcherType?.description ?? ""
		#endif
		
		return activity
	}
	
	func makeReadArticleActivity(fetcher: ArticleFetcher?, article: Article) -> NSUserActivity {
		let activity = NSUserActivity(activityType: ActivityType.readArticle.rawValue)
		activity.title = ArticleStringFormatter.truncatedTitle(article)
		
		if let fetcher = fetcher {
			let articleFetcherIdentifierUserInfo = fetcher.articleFetcherType?.userInfo ?? [AnyHashable: Any]()
			let articlePathUserInfo = article.pathUserInfo
			activity.userInfo = [UserInfoKey.feedIdentifier: articleFetcherIdentifierUserInfo, UserInfoKey.articlePath: articlePathUserInfo]
		} else {
			activity.userInfo = [UserInfoKey.articlePath: article.pathUserInfo]
		}
		activity.requiredUserInfoKeys = Set(activity.userInfo!.keys.map { $0 as! String })
		
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

		if let iconImage = article.iconImage() {
			attributeSet.thumbnailData = iconImage.image.pngData()
		}
		
		readingActivity?.contentAttributeSet = attributeSet
		readingActivity?.needsSave = true
		
	}
	#endif
	
	func makeKeywords(_ article: Article) -> [String] {
		let feedNameKeywords = makeKeywords(article.webFeed?.nameForDisplay)
		let articleTitleKeywords = makeKeywords(ArticleStringFormatter.truncatedTitle(article))
		return feedNameKeywords + articleTitleKeywords
	}
	
	func makeKeywords(_ value: String?) -> [String] {
		return value?.components(separatedBy: " ").filter { $0.count > 2 } ?? []
	}
	
	func updateSelectingActivityFeedSearchAttributes(with feed: WebFeed) {
		
		let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
		attributeSet.title = feed.nameForDisplay
		attributeSet.keywords = makeKeywords(feed.nameForDisplay)
		attributeSet.relatedUniqueIdentifier = ActivityManager.identifer(for: feed)
		if let iconImage = appDelegate.webFeedIconDownloader.icon(for: feed) {
			attributeSet.thumbnailData = iconImage.image.dataRepresentation()
		} else if let iconImage = appDelegate.faviconDownloader.faviconAsIcon(for: feed) {
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
			let tempAttributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
			let searchableItem = CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: nil, attributeSet: tempAttributeSet)
			CSSearchableIndex.default().indexSearchableItems([searchableItem])
		}
		
		activity.becomeCurrent()
	}
	
	static func identifer(for folder: Folder) -> String {
		return "account_\(folder.account!.accountID)_folder_\(folder.nameForDisplay)"
	}
	
	static func identifer(for feed: WebFeed) -> String {
		return "account_\(feed.account!.accountID)_feed_\(feed.webFeedID)"
	}
	
	static func identifer(for article: Article) -> String {
		return "account_\(article.accountID)_feed_\(article.webFeedID)_article_\(article.articleID)"
	}
	
	static func identifers(for feed: WebFeed) -> [String] {
		var ids = [String]()
		ids.append(identifer(for: feed))
		
		for article in feed.fetchArticles() {
			ids.append(identifer(for: article))
		}
		
		return ids
	}
	
}
