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

@MainActor final class WidgetDataEncoder {
	static let shared = WidgetDataEncoder()

	var isRunning = false

	private let fetchLimit = 7
	private let imageContainer: URL
	private let dataURL: URL

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "WidgetDataEncoder")

	init?() {
		guard let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String else {
			Self.logger.error("WidgetDataEncoder: unable to create appGroup")
			return nil
		}
		guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
			Self.logger.error("WidgetDataEncoder: unable to create containerURL")
			return nil
		}

		self.imageContainer = containerURL.appendingPathComponent("widgetImages", isDirectory: true)
		self.dataURL = containerURL.appendingPathComponent("widget-data.json")

		do {
			try FileManager.default.createDirectory(at: imageContainer, withIntermediateDirectories: true, attributes: nil)
		} catch {
			Self.logger.error("WidgetDataEncoder: unable to create folder for images")
			return nil
		}
	}

	func encode() {
		guard !isRunning else {
			Self.logger.debug("WidgetDataEncoder: skipping encode because already in encode")
			return
		}

		isRunning = true
		defer { isRunning = false }

		removeStaleFaviconsFromSharedContainer()

		let latestData: WidgetData
		do {
			latestData = try fetchWidgetData()
			Self.logger.debug("WidgetDataEncoder: fetched latest widget data")
		} catch {
			Self.logger.error("WidgetDataEncoder: error fetching widget data: \(error.localizedDescription)")
			return
		}

		let encodedData: Data
		do {
			encodedData = try JSONEncoder().encode(latestData)
			Self.logger.debug("WidgetDataEncoder: encoded widget data")
		} catch {
			Self.logger.error("WidgetDataEncoder: error encoding widget data: \(error.localizedDescription)")
			return
		}

		do {
			let existingData = try? WidgetDataDecoder.decodeWidgetData()
			try encodedData.write(to: dataURL, options: [.atomic])
			reloadTimelines(newData: latestData, existingData: existingData)
			Self.logger.debug("WidgetDataEncoder: finished refreshing widget data")
		} catch {
			Self.logger.error("WidgetDataEncoder: could not write data to container")
		}
	}

	func reloadTimelines(newData: WidgetData, existingData: WidgetData?) {
		if let existingData = existingData {
			var shouldRefreshSummary = false

			if existingData.unreadArticles != newData.unreadArticles {
				WidgetCenter.shared.reloadTimelines(ofKind: "com.ranchero.NetNewsWire.UnreadWidget")
				shouldRefreshSummary = true
				Self.logger.debug("WidgetDataEncoder: Reloading Unread widget")
			}

			if existingData.todayArticles != newData.todayArticles || existingData.totalTodayUnreadCount != newData.totalTodayUnreadCount {
				WidgetCenter.shared.reloadTimelines(ofKind: "com.ranchero.NetNewsWire.TodayWidget")
				shouldRefreshSummary = true
				Self.logger.debug("WidgetDataEncoder: Reloading Today widget")
			}

			if existingData.starredArticles != newData.starredArticles {
				WidgetCenter.shared.reloadTimelines(ofKind: "com.ranchero.NetNewsWire.StarredWidget")
				shouldRefreshSummary = true
				Self.logger.debug("WidgetDataEncoder: Reloading Starred widget")
			}

			if shouldRefreshSummary {
				WidgetCenter.shared.reloadTimelines(ofKind: "com.ranchero.NetNewsWire.LockScreenSummaryWidget")
				Self.logger.debug("WidgetDataEncoder: Reloading Summary widget")
			}
		}
	}

}

@MainActor private extension WidgetDataEncoder {

	func fetchWidgetData() throws -> WidgetData {
		let fetchedUnreadArticles = try AccountManager.shared.fetchArticles(.unread(fetchLimit))
		let unreadArticles = sortedLatestArticles(fetchedUnreadArticles)

		let fetchedStarredArticles = try AccountManager.shared.fetchArticles(.starred(fetchLimit))
		let starredArticles = sortedLatestArticles(fetchedStarredArticles)

		let fetchedTodayArticles = try AccountManager.shared.fetchArticles(.today(fetchLimit))
		let fetchedTodayTotal = try AccountManager.shared.fetchArticles(.today())
		let fetchedTodayTotalCount = fetchedTodayTotal.count
		let fetchedTodayUnreadCount = fetchedTodayTotal.filter({ $0.status.read == false }).count
		let todayArticles = sortedLatestArticles(fetchedTodayArticles)

		let latestData = WidgetData(totalUnreadCount: SmartFeedsController.shared.unreadFeed.unreadCount,
									totalTodayCount: fetchedTodayTotalCount,
									totalTodayUnreadCount: fetchedTodayUnreadCount,
									totalStarredCount: (try? AccountManager.shared.fetchCountForStarredArticles()) ?? 0,
									unreadArticles: unreadArticles,
									starredArticles: starredArticles,
									todayArticles: todayArticles,
									lastUpdateTime: Date.now)
		
		return latestData
	}

	func fileExists() -> Bool {
		FileManager.default.fileExists(atPath: dataURL.path)
	}

	func writeImageDataToSharedContainer(_ imageData: Data?) -> String? {
		guard let imageData, let md5 = imageData.md5String else {
			return nil
		}

		let imagePath = imageContainer.appendingPathComponent(md5, isDirectory: false)
		let fm = FileManager.default
		if fm.fileExists(atPath: imagePath.path) {
			Self.logger.debug("WidgetDataEncoder: favicon already exists. Will not write again.")
			return imagePath.path
		}
		do {
			try imageData.write(to: imagePath)
			return imagePath.path
		} catch {
			return nil
		}
	}

	func removeStaleFaviconsFromSharedContainer() {
		let fm = FileManager.default
		if !fm.fileExists(atPath: imageContainer.path) {
			try? fm.createDirectory(at: imageContainer, withIntermediateDirectories: true, attributes: nil)
			return
		}

		/// We don't have 7 days to test in DEBUG mode.
		/// So, for testing purposes, images are removed after 30s
		/// if they haven't been accessed.
		#if DEBUG
		let cutoffDate = Date.now.addingTimeInterval(-30)
		#else
		let cutoffDate = Date.now.addingTimeInterval(-7 * 24 * 60 * 60)
		#endif

		do {
			let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .contentAccessDateKey, .contentModificationDateKey]
			let urls = try fm.contentsOfDirectory(at: imageContainer, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles])
			for url in urls {
				let values = try url.resourceValues(forKeys: resourceKeys)
				// Skip directories; we only store files in this container
				if values.isDirectory == true { continue }

				// Prefer last access date; fall back to modification date if needed
				let lastAccess = values.contentAccessDate ?? values.contentModificationDate
				if let lastAccess, lastAccess < cutoffDate {
					try? fm.removeItem(at: url)
				}
			}
		} catch {
			Self.logger.debug("WidgetDataEncoder: unable to remove favicons: \(error.localizedDescription).")
		}
	}

	func createLatestArticle(_ article: Article) -> LatestArticle {
		let truncatedTitle = ArticleStringFormatter.truncatedTitle(article)
		let articleTitle = truncatedTitle.isEmpty ? ArticleStringFormatter.truncatedSummary(article) : truncatedTitle

		let feedIconPath = writeImageDataToSharedContainer(article.iconImage()?.image.dataRepresentation())

		let pubDate = article.datePublished?.description ?? ""

		let latestArticle = LatestArticle(id: article.sortableArticleID,
										  feedTitle: article.sortableName,
										  articleTitle: articleTitle,
										  articleSummary: article.summary,
										  feedIconPath: feedIconPath,
										  pubDate: pubDate)
		return latestArticle
	}

	func sortedLatestArticles(_ fetchedArticles: Set<Article>) -> [LatestArticle] {
		let latestArticles = fetchedArticles.map(createLatestArticle)
		return latestArticles.sorted(by: { $0.pubDate > $1.pubDate })
	}
}
