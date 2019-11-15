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
		guard let articles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		let identifiers = articles.filter({ $0.status.read }).map { "articleID:\($0.articleID)" }
		UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
	}
	
}

private extension UserNotificationManager {
	
	private func sendNotification(webFeed: WebFeed, article: Article) {
		let content = UNMutableNotificationContent()
						
		content.title = webFeed.nameForDisplay
		content.body = ArticleStringFormatter.truncatedTitle(article)
		if content.body.isEmpty {
			content.body = ArticleStringFormatter.truncatedSummary(article)
		}

		content.sound = UNNotificationSound.default
		content.userInfo = [UserInfoKey.articlePath: article.pathUserInfo]

		let request = UNNotificationRequest.init(identifier: "articleID:\(article.articleID)", content: content, trigger: nil)
		UNUserNotificationCenter.current().add(request)
	}
	
}
