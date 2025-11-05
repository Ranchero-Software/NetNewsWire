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

final class UserNotificationManager {
	static let shared = UserNotificationManager()

	static private let notificationCategory = "NEW_ARTICLE_NOTIFICATION_CATEGORY"

	struct ActionIdentifier {
		static let markAsRead = "MARK_AS_READ"
		static let markAsStarred = "MARK_AS_STARRED"
		static let openArticle = "OPEN_ARTICLE"
	}

	@MainActor private var isActive = false

	@MainActor func start() {
		guard !isActive else {
			assertionFailure("start called when already active")
			return
		}

		NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		registerCategoriesAndActions()

		isActive = true
	}

	@objc func accountDidDownloadArticles(_ note: Notification) {
		guard let articles = note.userInfo?[Account.UserInfoKey.newArticles] as? Set<Article> else {
			return
		}

		for article in articles {
			if !article.status.read, let feed = article.feed, feed.isNotifyAboutNewArticles ?? false {
				sendNotification(feed: feed, article: article)
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

	func sendNotification(feed: Feed, article: Article) {
		let content = UNMutableNotificationContent()

		content.title = feed.nameForDisplay
		if !ArticleStringFormatter.truncatedTitle(article).isEmpty {
			content.subtitle = ArticleStringFormatter.truncatedTitle(article)
		}
		content.body = ArticleStringFormatter.truncatedSummary(article)
		content.threadIdentifier = feed.feedID
		content.sound = UNNotificationSound.default
		content.userInfo = [UserInfoKey.articlePath: article.pathUserInfo]
		content.categoryIdentifier = Self.notificationCategory
		if let attachment = thumbnailAttachment(for: article, feed: feed) {
			content.attachments.append(attachment)
		}

		let request = UNNotificationRequest.init(identifier: "articleID:\(article.articleID)", content: content, trigger: nil)
		UNUserNotificationCenter.current().add(request)
	}

	/// Determine if there is an available icon for the article. This will then move it to the caches directory and make it avialble for the notification. 
	/// - Parameters:
	///   - article: `Article`
	///   - feed: `Feed`
	/// - Returns: A `UNNotifcationAttachment` if an icon is available. Otherwise nil.
	/// - Warning: In certain scenarios, this will return the `faviconTemplateImage`.
	func thumbnailAttachment(for article: Article, feed: Feed) -> UNNotificationAttachment? {
		if let imageURL = article.iconImageUrl(feed: feed) {
			let thumbnail = try? UNNotificationAttachment(identifier: feed.feedID, url: imageURL, options: nil)
			return thumbnail
		}
		return nil
	}

	func registerCategoriesAndActions() {
		let readAction = UNNotificationAction(identifier: ActionIdentifier.markAsRead, title: NSLocalizedString("Mark as Read", comment: "Mark as Read"), options: [])
		let starredAction = UNNotificationAction(identifier: ActionIdentifier.markAsStarred, title: NSLocalizedString("Mark as Starred", comment: "Mark as Starred"), options: [])
		let openAction = UNNotificationAction(identifier: ActionIdentifier.openArticle, title: NSLocalizedString("Open", comment: "Open"), options: [.foreground])

		let newArticleCategory = UNNotificationCategory(identifier: Self.notificationCategory,
														actions: [openAction, readAction, starredAction],
														intentIdentifiers: [],
														hiddenPreviewsBodyPlaceholder: "",
														options: [])

		UNUserNotificationCenter.current().setNotificationCategories([newArticleCategory])
	}
}
