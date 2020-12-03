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


public final class WidgetDataEncoder {
	
	private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Application")
	
	private var backgroundTaskID: UIBackgroundTaskIdentifier!
	private lazy var appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
	private lazy var containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
	private lazy var dataURL = containerURL?.appendingPathComponent("widget-data.json")
	
	static let shared = WidgetDataEncoder()
	private init () {}
	
	@available(iOS 14, *)
	func encodeWidgetData(refreshTimeline: Bool = true) throws {
		os_log(.debug, log: log, "Starting encoding widget data.")
		
		do {
			let unreadArticles = Array(try SmartFeedsController.shared.unreadFeed.fetchArticles()).sortedByDate(.orderedDescending)
			
			let starredArticles = Array(try SmartFeedsController.shared.starredFeed.fetchArticles()).sortedByDate(.orderedDescending)
			
			let todayArticles = Array(try SmartFeedsController.shared.todayFeed.fetchUnreadArticles()).sortedByDate(.orderedDescending)
			
			var unread = [LatestArticle]()
			var today = [LatestArticle]()
			var starred = [LatestArticle]()
			
			for article in unreadArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? article.contentHTML?.strippingHTML().trimmingWhitespace : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIcon: article.iconImage()?.image.dataRepresentation(),
												  pubDate: article.datePublished!.description)
				unread.append(latestArticle)
				if unread.count == 7 { break }
			}
			
			for article in starredArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? article.contentHTML?.strippingHTML().trimmingWhitespace : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIcon: article.iconImage()?.image.dataRepresentation(),
												  pubDate: article.datePublished!.description)
				starred.append(latestArticle)
				if starred.count == 7 { break }
			}
			
			for article in todayArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? article.contentHTML?.strippingHTML().trimmingWhitespace : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIcon: article.iconImage()?.image.dataRepresentation(),
												  pubDate: article.datePublished!.description)
				today.append(latestArticle)
				if today.count == 7 { break }
			}
			
			let latestData = WidgetData(currentUnreadCount: SmartFeedsController.shared.unreadFeed.unreadCount,
										currentTodayCount: try! SmartFeedsController.shared.todayFeed.fetchUnreadArticles().count,
										currentStarredCount: try! SmartFeedsController.shared.starredFeed.fetchArticles().count,
										unreadArticles: unread,
										starredArticles: starred,
										todayArticles:today,
										lastUpdateTime: Date())
			
			
			DispatchQueue.global().async { [weak self] in
				guard let self = self else { return }
				
				self.backgroundTaskID = UIApplication.shared.beginBackgroundTask (withName: "com.ranchero.NetNewsWire.Encode") {
					 UIApplication.shared.endBackgroundTask(self.backgroundTaskID!)
					self.backgroundTaskID = .invalid
				}
				let encodedData = try? JSONEncoder().encode(latestData)
				
				os_log(.debug, log: self.log, "Finished encoding widget data.")
				
				if self.fileExists() {
					try? FileManager.default.removeItem(at: self.dataURL!)
					os_log(.debug, log: self.log, "Removed widget data from container.")
				}
				if FileManager.default.createFile(atPath: self.dataURL!.path, contents: encodedData, attributes: nil) {
					os_log(.debug, log: self.log, "Wrote widget data to container.")
					if refreshTimeline == true {
						WidgetCenter.shared.reloadAllTimelines()
						UIApplication.shared.endBackgroundTask(self.backgroundTaskID!)
						self.backgroundTaskID = .invalid
					} else {
						UIApplication.shared.endBackgroundTask(self.backgroundTaskID!)
						self.backgroundTaskID = .invalid
					}
				} else {
					UIApplication.shared.endBackgroundTask(self.backgroundTaskID!)
					self.backgroundTaskID = .invalid
				}
				
			}
		}
	}
	
	private func fileExists() -> Bool {
		FileManager.default.fileExists(atPath: dataURL!.path)
	}
	
}

