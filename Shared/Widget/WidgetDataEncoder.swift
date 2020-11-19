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

@available(iOS 14, *)
struct WidgetDataEncoder {
	
	static let taskIdentifier = "com.ranchero.NetNewsWire.WidgetEncode"
	
	static func encodeWidgetData() {
		os_log(.info, "Starting widget data encoding")
		do {
			// Unread Articles
			let unreadArticles = try SmartFeedsController.shared.unreadFeed.fetchArticles().sorted(by: { $0.datePublished ?? .distantPast > $1.datePublished ?? .distantPast  })
			var unread = [LatestArticle]()
			for article in unreadArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? article.contentHTML?.strippingHTML().trimmingWhitespace : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIcon: article.iconImage()?.image.dataRepresentation(),
												  pubDate: article.datePublished!.description)
				unread.append(latestArticle)
				if unread.count == 8 { break }
			}
			
			// Starred Articles
			let starredArticles = try SmartFeedsController.shared.starredFeed.fetchArticles().sorted(by: { $0.datePublished  ?? .distantPast > $1.datePublished ?? .distantPast  })
			var starred = [LatestArticle]()
			for article in starredArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? article.contentHTML?.strippingHTML().trimmingWhitespace : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIcon: article.iconImage()?.image.dataRepresentation(),
												  pubDate: article.datePublished!.description)
				starred.append(latestArticle)
				if starred.count == 8 { break }
			}
			
			// Today Articles
			let todayArticles = try SmartFeedsController.shared.todayFeed.fetchUnreadArticles().sorted(by: { $0.datePublished ?? .distantPast > $1.datePublished  ?? .distantPast })
			var today = [LatestArticle]()
			for article in todayArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? article.contentHTML?.strippingHTML().trimmingWhitespace : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIcon: article.iconImage()?.image.dataRepresentation(),
												  pubDate: article.datePublished!.description)
				today.append(latestArticle)
				if today.count == 8 { break }
			}
			
			let latestData = WidgetData(currentUnreadCount: SmartFeedsController.shared.unreadFeed.unreadCount,
										currentTodayCount: try! SmartFeedsController.shared.todayFeed.fetchUnreadArticles().count,
										currentStarredCount: try! SmartFeedsController.shared.starredFeed.fetchArticles().count,
										unreadArticles: unread,
										starredArticles: starred,
										todayArticles:today,
										lastUpdateTime: Date())
			
			let encodedData = try JSONEncoder().encode(latestData)
			let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
			let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
			let dataURL = containerURL?.appendingPathComponent("widget-data.json")
			if FileManager.default.fileExists(atPath: dataURL!.path) {
				try FileManager.default.removeItem(at: dataURL!)
			}
			try encodedData.write(to: dataURL!)
			WidgetCenter.shared.reloadAllTimelines()
			os_log(.info, "Finished encoding widget data")
		} catch {
			os_log(.error, "%@", error.localizedDescription)
		}
	}
	
	
}

