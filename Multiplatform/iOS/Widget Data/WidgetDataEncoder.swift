//
//  WidgetDataEncoder.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 11/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import WidgetKit
import os.log
import UIKit

struct WidgetDataEncoder {
	
	static let taskIdentifier = "com.ranchero.NetNewsWire.WidgetEncode"
	
	static func encodeWidgetData() {
		os_log(.info, "Starting widget data encoding")
		let task = UIApplication.shared.beginBackgroundTask(withName: taskIdentifier, expirationHandler: nil)
		do {
			let articles = try SmartFeedsController.shared.unreadFeed.fetchArticles().sorted(by: { $0.datePublished! > $1.datePublished!  })
			var latest = [LatestArticle]()
			for article in articles {
				let latestArticle = LatestArticle(feedTitle: article.sortableName,
												  articleTitle: article.title,
												  articleSummary: article.summary,
												  feedIcon: article.iconImage()?.image.dataRepresentation(),
												  pubDate: article.datePublished!.description)
				latest.append(latestArticle)
				if latest.count == 5 { break }
			}
			
			let latestData = WidgetData(currentUnreadCount: SmartFeedsController.shared.unreadFeed.unreadCount,
										currentTodayCount: SmartFeedsController.shared.todayFeed.unreadCount,
										latestArticles: latest,
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
			print(UIApplication.shared.backgroundTimeRemaining)
			UIApplication.shared.endBackgroundTask(task)
		} catch {
			os_log(.error, "%@", error.localizedDescription)
			UIApplication.shared.endBackgroundTask(task)
		}
	}
	
	
}
