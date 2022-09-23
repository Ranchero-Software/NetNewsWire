//
//  WidgetDataEncoder.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import WidgetKit
import UIKit
import RSCore
import Articles
import Account


public final class WidgetDataEncoder: Logging {
	
	
	private let fetchLimit = 7
	
	private lazy var appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
	private lazy var containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
	private lazy var imageContainer = containerURL?.appendingPathComponent("widgetImages", isDirectory: true)
	private lazy var dataURL = containerURL?.appendingPathComponent("widget-data.json")
	
	private let encodeWidgetDataQueue = CoalescingQueue(name: "Encode the Widget Data", interval: 5.0)

	init () {
		if imageContainer != nil {
			try? FileManager.default.createDirectory(at: imageContainer!, withIntermediateDirectories: true, attributes: nil)
		}
		if #available(iOS 14, *) {
			NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		}
	}
	
	func encodeIfNecessary() {
		encodeWidgetDataQueue.performCallsImmediately()
	}

	@available(iOS 14, *)
	@objc func statusesDidChange(_ note: Notification) {
		encodeWidgetDataQueue.add(self, #selector(performEncodeWidgetData))
	}

	@available(iOS 14, *)
	@objc private func performEncodeWidgetData() {
		// We will be on the Main Thread when the encodeIfNecessary function is called. We want
		// block the main thread in that case so that the widget data is encoded. If it is on
		// a background Thread, it was called by the CoalescingQueue. In that case we need to
		// move it to the Main Thread and want to execute it async.
		if Thread.isMainThread {
			encodeWidgetData()
		} else {
			DispatchQueue.main.async {
				self.encodeWidgetData()
			}
		}
	}
	
	@available(iOS 14, *)
	private func encodeWidgetData() {
		flushSharedContainer()
		logger.debug("Starting encoding widget data.")
		
		do {
			let unreadArticles = Array(try AccountManager.shared.fetchArticles(.unread(fetchLimit))).sortedByDate(.orderedDescending)
			let starredArticles = Array(try AccountManager.shared.fetchArticles(.starred(fetchLimit))).sortedByDate(.orderedDescending)
			let todayArticles = Array(try AccountManager.shared.fetchArticles(.today(fetchLimit))).sortedByDate(.orderedDescending)
			
			var unread = [LatestArticle]()
			var today = [LatestArticle]()
			var starred = [LatestArticle]()
			
			for article in unreadArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? ArticleStringFormatter.truncatedSummary(article) : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIconPath: writeImageDataToSharedContainer(article.iconImage()?.image.dataRepresentation()),
												  pubDate: article.datePublished?.description ?? "")
				unread.append(latestArticle)
			}
			
			for article in starredArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? ArticleStringFormatter.truncatedSummary(article) : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIconPath: writeImageDataToSharedContainer(article.iconImage()?.image.dataRepresentation()),
												  pubDate: article.datePublished?.description ?? "")
				starred.append(latestArticle)
			}
			
			for article in todayArticles {
				let latestArticle = LatestArticle(id: article.sortableArticleID,
												  feedTitle: article.sortableName,
												  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? ArticleStringFormatter.truncatedSummary(article) : ArticleStringFormatter.truncatedTitle(article),
												  articleSummary: article.summary,
												  feedIconPath: writeImageDataToSharedContainer(article.iconImage()?.image.dataRepresentation()),
												  pubDate: article.datePublished?.description ?? "")
				today.append(latestArticle)
			}
			
			let latestData = WidgetData(currentUnreadCount: SmartFeedsController.shared.unreadFeed.unreadCount,
										currentTodayCount: SmartFeedsController.shared.todayFeed.unreadCount,
										currentStarredCount: try AccountManager.shared.fetchCountForStarredArticles(),
										unreadArticles: unread,
										starredArticles: starred,
										todayArticles:today,
										lastUpdateTime: Date())
			
			
			DispatchQueue.global().async { [weak self] in
				guard let self = self else { return }
				
				let encodedData = try? JSONEncoder().encode(latestData)
				
				self.logger.debug("Finished encoding widget data.")
				
				if self.fileExists() {
					try? FileManager.default.removeItem(at: self.dataURL!)
					self.logger.debug("Removed widget data from container.")
				}
				if FileManager.default.createFile(atPath: self.dataURL!.path, contents: encodedData, attributes: nil) {
					self.logger.debug("Wrote widget data to container.")
					WidgetCenter.shared.reloadAllTimelines()
				}
				
			}
		} catch {
			logger.error("WidgetDataEncoder failed to write the widget data.")
		}
	}
	
	private func fileExists() -> Bool {
		FileManager.default.fileExists(atPath: dataURL!.path)
	}
	
	private func writeImageDataToSharedContainer(_ imageData: Data?) -> String? {
		if imageData == nil { return nil }
		// Each image gets a UUID
		let uuid = UUID().uuidString
		if let imagePath = imageContainer?.appendingPathComponent(uuid, isDirectory: false) {
			do {
				try imageData!.write(to: imagePath)
				return imagePath.path
			} catch {
				return nil
			}
		}
		
		return nil
	}
	
	private func flushSharedContainer() {
		if let imageContainer = imageContainer {
			try? FileManager.default.removeItem(atPath: imageContainer.path)
			try? FileManager.default.createDirectory(at: imageContainer, withIntermediateDirectories: true, attributes: nil)
		}
	}
	
}

