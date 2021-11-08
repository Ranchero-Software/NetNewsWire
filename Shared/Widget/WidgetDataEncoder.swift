//
//  WidgetDataEncoder.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import WidgetKit
import os.log
import UIKit
import RSCore
import Articles
import Account


public final class WidgetDataEncoder {
	
	private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Application")
	private let fetchLimit = 7
	
	private var backgroundTaskID: UIBackgroundTaskIdentifier!
	private lazy var appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
	private lazy var containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
	private lazy var dataURL = containerURL?.appendingPathComponent("widget-data.json")
	
	static let shared = WidgetDataEncoder()
	private init () {}
	
	@available(iOS 14, *)
	func encodeWidgetDataSync() throws {
		
		os_log(.debug, log: log, "Starting encoding widget data.")

		do {

			let unreadArticles = Array(try AccountManager.shared.fetchArticles(.unread(self.fetchLimit))).sortedByDate(.orderedDescending)
			let starredArticles = Array(try AccountManager.shared.fetchArticles(.starred(self.fetchLimit))).sortedByDate(.orderedDescending)
			let todayArticles = Array(try AccountManager.shared.fetchArticles(.today(self.fetchLimit))).sortedByDate(.orderedDescending)
			
			var unread = [LatestArticle]()
			var today = [LatestArticle]()
			var starred = [LatestArticle]()
			
			for article in unreadArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? ArticleStringFormatter.truncatedSummary(article) : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIcon: article.iconImage()?.image.dataRepresentation(),
												  pubDate: article.datePublished?.description ?? "")
				unread.append(latestArticle)
			}
			
			for article in starredArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? ArticleStringFormatter.truncatedSummary(article) : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIcon: article.iconImage()?.image.dataRepresentation(),
												  pubDate: article.datePublished?.description ?? "")
				starred.append(latestArticle)
			}
			
			for article in todayArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? ArticleStringFormatter.truncatedSummary(article) : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIcon: article.iconImage()?.image.dataRepresentation(),
												  pubDate: article.datePublished?.description ?? "")
				today.append(latestArticle)
			}
			
			let latestData = WidgetData(currentUnreadCount: SmartFeedsController.shared.unreadFeed.unreadCount,
										currentTodayCount: SmartFeedsController.shared.todayFeed.unreadCount,
										currentStarredCount: try! SmartFeedsController.shared.starredFeed.fetchArticles().count,
										unreadArticles: unread,
										starredArticles: starred,
										todayArticles:today,
										lastUpdateTime: Date())
			
			
			let encodedData = try JSONEncoder().encode(latestData)
			os_log(.debug, log: self.log, "Finished encoding widget data.")
			
			if self.fileExists() {
				try? FileManager.default.removeItem(at: self.dataURL!)
				os_log(.debug, log: self.log, "Removed widget data from container.")
			}
			if FileManager.default.createFile(atPath: self.dataURL!.path, contents: encodedData, attributes: nil) {
				os_log(.debug, log: self.log, "Wrote widget data to container.")
				WidgetCenter.shared.reloadAllTimelines()
			}
		} catch {
			print(error.localizedDescription)
		}
	}
	
	@available(iOS 14, *)
	func encodeWidgetDataAsync() throws {
		DispatchQueue.main.async {
			try? self.encodeWidgetDataSync()
		}
	}
	
	private func fileExists() -> Bool {
		FileManager.default.fileExists(atPath: dataURL!.path)
	}
	
}

