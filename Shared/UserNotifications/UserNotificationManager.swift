//
//  NotificationManager.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/2/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Articles
import UserNotifications

final class UserNotificationManager: NSObject {
	
	override init() {
		super.init()
		NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		registerCategoriesAndActions()
	}
	
	@objc func accountDidDownloadArticles(_ note: Notification) {
		guard let articles = note.userInfo?[Account.UserInfoKey.newArticles] as? Set<Article> else {
			return
		}
		
		for article in articles {
			if !article.status.read, let webFeed = article.webFeed, webFeed.isNotifyAboutNewArticles ?? false {
				sendNotification(webFeed: webFeed, article: article)
			}
		}
	}

	@objc func statusesDidChange(_ note: Notification) {
		if let statuses = note.userInfo?[Account.UserInfoKey.statuses] as? Set<ArticleStatus>, !statuses.isEmpty {
			let identifiers = statuses.filter({ $0.read }).map { "articleID:\($0.articleID)" }
			UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
			return
		}
		
		if let articleIDs = note.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String>,
		   let statusKey = note.userInfo?[Account.UserInfoKey.statusKey] as? ArticleStatus.Key,
		   let flag = note.userInfo?[Account.UserInfoKey.statusFlag] as? Bool,
		   statusKey == .read,
		   flag == true {
			let identifiers = articleIDs.map { "articleID:\($0)" }
			UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
		}
	}
	
}

private extension UserNotificationManager {
	
	func sendNotification(webFeed: WebFeed, article: Article) {
		let content = UNMutableNotificationContent()
						
		content.title = webFeed.nameForDisplay
		if !ArticleStringFormatter.truncatedTitle(article).isEmpty {
			content.subtitle = ArticleStringFormatter.truncatedTitle(article)
		}
		content.body = ArticleStringFormatter.truncatedSummary(article)
		content.threadIdentifier = webFeed.webFeedID
		content.sound = UNNotificationSound.default
		content.userInfo = [UserInfoKey.articlePath: article.pathUserInfo]
		content.categoryIdentifier = "NEW_ARTICLE_NOTIFICATION_CATEGORY"
		if let attachment = thumbnailAttachment(for: article, webFeed: webFeed) {
			content.attachments.append(attachment)
		}
		
		let request = UNNotificationRequest.init(identifier: "articleID:\(article.articleID)", content: content, trigger: nil)
		UNUserNotificationCenter.current().add(request)
	}
	
	/// Determine if there is an available icon for the article. This will then move it to the caches directory and make it avialble for the notification. 
	/// - Parameters:
	///   - article: `Article`
	///   - webFeed: `WebFeed`
	/// - Returns: A `UNNotifcationAttachment` if an icon is available. Otherwise nil.
	/// - Warning: In certain scenarios, this will return the `faviconTemplateImage`.
	func thumbnailAttachment(for article: Article, webFeed: WebFeed) -> UNNotificationAttachment? {
		if let imageURL = article.iconImageUrl(webFeed: webFeed) {
			let thumbnail = try? UNNotificationAttachment(identifier: webFeed.webFeedID, url: imageURL, options: nil)
			return thumbnail
		}
		return nil
	}
	
	func registerCategoriesAndActions() {
		let readAction = UNNotificationAction(identifier: "MARK_AS_READ", title: NSLocalizedString("MARK_AS_READ_TITLECASE", comment: "Mark as Read"), options: [])
		let starredAction = UNNotificationAction(identifier: "MARK_AS_STARRED", title: NSLocalizedString("MARK_AS_STARRED_TITLECASE", comment: "Mark as Starred"), options: [])
		let openAction = UNNotificationAction(identifier: "OPEN_ARTICLE", title: NSLocalizedString("OPEN", comment: "Open"), options: [.foreground])
		
		let newArticleCategory =
			  UNNotificationCategory(identifier: "NEW_ARTICLE_NOTIFICATION_CATEGORY",
			  actions: [openAction, readAction, starredAction],
			  intentIdentifiers: [],
			  hiddenPreviewsBodyPlaceholder: "",
			  options: [])
		
		UNUserNotificationCenter.current().setNotificationCategories([newArticleCategory])
	}
	
}
