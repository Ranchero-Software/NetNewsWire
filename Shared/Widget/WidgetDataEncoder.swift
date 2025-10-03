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
	public var isRunning = false

	private let fetchLimit = 7

	private lazy var appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
	private lazy var containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
	private lazy var imageContainer = containerURL?.appendingPathComponent("widgetImages", isDirectory: true)
	private lazy var dataURL = containerURL?.appendingPathComponent("widget-data.json")

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "WidgetDataEncoder")

	init () {
		if imageContainer != nil {
			try? FileManager.default.createDirectory(at: imageContainer!, withIntermediateDirectories: true, attributes: nil)
		}
	}

	func encode() {
		if #available(iOS 14, *) {
			isRunning = true

			flushSharedContainer()
			Self.logger.debug("Encoding widget data")

			DispatchQueue.main.async {
				self.encodeWidgetData() { latestData in
					guard let latestData = latestData else {
						self.isRunning = false
						return
					}

					let encodedData = try? JSONEncoder().encode(latestData)

					Self.logger.debug("Finished encoding widget data")

					if self.fileExists() {
						try? FileManager.default.removeItem(at: self.dataURL!)
						Self.logger.debug("Removed widget data from container")
					}

					if FileManager.default.createFile(atPath: self.dataURL!.path, contents: encodedData, attributes: nil) {
						Self.logger.info("Wrote widget data to container")
						WidgetCenter.shared.reloadAllTimelines()
					}

					self.isRunning = false
				}
			}
		}
	}

	@available(iOS 14, *)
	private func encodeWidgetData(completion: @escaping (WidgetData?) -> Void) {
		let dispatchGroup = DispatchGroup()
		var groupError: Error? = nil

		var unread = [LatestArticle]()

		dispatchGroup.enter()
		AccountManager.shared.fetchArticlesAsync(.unread(fetchLimit)) { (articleSetResult) in
			switch articleSetResult {
			case .success(let articles):
				for article in articles {
					let latestArticle = LatestArticle(id: article.sortableArticleID,
													  feedTitle: article.sortableName,
													  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? ArticleStringFormatter.truncatedSummary(article) : ArticleStringFormatter.truncatedTitle(article),
													  articleSummary: article.summary,
													  feedIconPath: self.writeImageDataToSharedContainer(article.iconImage()?.image.dataRepresentation()),
													  pubDate: article.datePublished?.description ?? "")
					unread.append(latestArticle)
				}
			case .failure(let databaseError):
				groupError = databaseError
			}
			dispatchGroup.leave()
		}

		var starred = [LatestArticle]()

		dispatchGroup.enter()
		AccountManager.shared.fetchArticlesAsync(.starred(fetchLimit)) { (articleSetResult) in
			switch articleSetResult {
			case .success(let articles):
				for article in articles {
					let latestArticle = LatestArticle(id: article.sortableArticleID,
													  feedTitle: article.sortableName,
													  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? ArticleStringFormatter.truncatedSummary(article) : ArticleStringFormatter.truncatedTitle(article),
													  articleSummary: article.summary,
													  feedIconPath: self.writeImageDataToSharedContainer(article.iconImage()?.image.dataRepresentation()),
													  pubDate: article.datePublished?.description ?? "")
					starred.append(latestArticle)
				}
			case .failure(let databaseError):
				groupError = databaseError
			}
			dispatchGroup.leave()
		}

		var today = [LatestArticle]()

		dispatchGroup.enter()
		AccountManager.shared.fetchArticlesAsync(.today(fetchLimit)) { (articleSetResult) in
			switch articleSetResult {
			case .success(let articles):
				for article in articles {
					let latestArticle = LatestArticle(id: article.sortableArticleID,
													  feedTitle: article.sortableName,
													  articleTitle: ArticleStringFormatter.truncatedTitle(article).isEmpty ? ArticleStringFormatter.truncatedSummary(article) : ArticleStringFormatter.truncatedTitle(article),
													  articleSummary: article.summary,
													  feedIconPath: self.writeImageDataToSharedContainer(article.iconImage()?.image.dataRepresentation()),
													  pubDate: article.datePublished?.description ?? "")
					today.append(latestArticle)
				}
			case .failure(let databaseError):
				groupError = databaseError
			}
			dispatchGroup.leave()
		}

		dispatchGroup.notify(queue: .main) {
			if let groupError {
				Self.logger.error("WidgetDataEncoder failed to write the widget data: \(groupError.localizedDescription)")
				completion(nil)
			} else {
				let latestData = WidgetData(currentUnreadCount: SmartFeedsController.shared.unreadFeed.unreadCount,
											currentTodayCount: SmartFeedsController.shared.todayFeed.unreadCount,
											currentStarredCount: (try? AccountManager.shared.fetchCountForStarredArticles()) ?? 0,
											unreadArticles: unread,
											starredArticles: starred,
											todayArticles:today,
											lastUpdateTime: Date())
				completion(latestData)
			}
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
