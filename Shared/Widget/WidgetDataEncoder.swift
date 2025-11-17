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
		if isRunning {
			Self.logger.debug("WidgetDataEncoder: skipping encode because already in encode")
			return
		}

		Self.logger.debug("WidgetDataEncoder: encoding")
		isRunning = true

		flushSharedContainer()

		Task { @MainActor in
			defer {
				isRunning = false
			}

			let latestData: WidgetData
			do {
				latestData = try await fetchWidgetData()
			} catch {
				Self.logger.error("WidgetDataEncoder: error fetching widget data: \(error.localizedDescription)")
				return
			}

			let encodedData: Data
			do {
				encodedData = try JSONEncoder().encode(latestData)
			} catch {
				Self.logger.error("WidgetDataEncoder: error encoding widget data: \(error.localizedDescription)")
				return
			}

			if fileExists() {
				try? FileManager.default.removeItem(at: dataURL)
				Self.logger.debug("WidgetDataEncoder: removed widget data from container")
			}

			if FileManager.default.createFile(atPath: dataURL.path, contents: encodedData, attributes: nil) {
				Self.logger.debug("WidgetDataEncoder: wrote data to container")
				WidgetCenter.shared.reloadAllTimelines()
			} else {
				Self.logger.error("WidgetDataEncoder: could not write data to container")
			}
		}
	}
}

@MainActor private extension WidgetDataEncoder {

	func fetchWidgetData() async throws -> WidgetData {
		let fetchedUnreadArticles = try await AccountManager.shared.fetchArticlesAsync(.unread(fetchLimit))
		let unreadArticles = sortedLatestArticles(fetchedUnreadArticles)

		let fetchedStarredArticles = try await AccountManager.shared.fetchArticlesAsync(.starred(fetchLimit))
		let starredArticles = sortedLatestArticles(fetchedStarredArticles)

		let fetchedTodayArticles = try await AccountManager.shared.fetchArticlesAsync(.today(fetchLimit))
		let todayArticles = sortedLatestArticles(fetchedTodayArticles)

		let latestData = WidgetData(currentUnreadCount: SmartFeedsController.shared.unreadFeed.unreadCount,
									currentTodayCount: SmartFeedsController.shared.todayFeed.unreadCount,
									currentStarredCount: (try? AccountManager.shared.fetchCountForStarredArticles()) ?? 0,
									unreadArticles: unreadArticles,
									starredArticles: starredArticles,
									todayArticles: todayArticles,
									lastUpdateTime: Date())
		return latestData
	}

	func fileExists() -> Bool {
		FileManager.default.fileExists(atPath: dataURL.path)
	}

	func writeImageDataToSharedContainer(_ imageData: Data?) -> String? {
		guard let imageData else {
			return nil
		}

		// Each image gets a UUID
		let uuid = UUID().uuidString

		let imagePath = imageContainer.appendingPathComponent(uuid, isDirectory: false)
		do {
			try imageData.write(to: imagePath)
			return imagePath.path
		} catch {
			return nil
		}
	}

	func flushSharedContainer() {
		try? FileManager.default.removeItem(atPath: imageContainer.path)
		try? FileManager.default.createDirectory(at: imageContainer, withIntermediateDirectories: true, attributes: nil)
	}

	func createLatestArticle(_ article: Article) -> LatestArticle {
		let truncatedTitle = ArticleStringFormatter.truncatedTitle(article)
		let articleTitle = truncatedTitle.isEmpty ? ArticleStringFormatter.truncatedSummary(article) : truncatedTitle

		// TODO: It looks like we write images each time, but we’re probably over-writing unchanged images sometimes.
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
