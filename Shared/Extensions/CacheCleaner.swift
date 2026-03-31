//
//  CacheCleaner.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import os
import RSWeb

struct CacheCleaner {

	static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CacheCleaner")

	private static let didPurgeImageCachesForResizingKey = "didPurgeImageCachesForResizing"

	static func purgeIfNecessary() {

		purgeImageCachesForResizingIfNeeded()

		guard let flushDate = AppDefaults.shared.lastImageCacheFlushDate else {
			AppDefaults.shared.lastImageCacheFlushDate = Date()
			return
		}

		// If the image disk cache hasn't been flushed for 3 days and the network is available, delete it
		if flushDate.addingTimeInterval(3600 * 24 * 3) < Date() {
			if NetworkMonitor.shared.isConnected {

				let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
				let faviconsFolderURL = tempDir.appendingPathComponent("Favicons")
				let imagesFolderURL = tempDir.appendingPathComponent("Images")
				let feedURLToIconURL = tempDir.appendingPathComponent("FeedURLToIconURLCache.plist")
				let homePageToIconURL = tempDir.appendingPathComponent("HomePageToIconURLCache.plist")
				let homePagesWithNoIconURL = tempDir.appendingPathComponent("HomePagesWithNoIconURLCache.plist")

				for tempItem in [faviconsFolderURL, imagesFolderURL, feedURLToIconURL, homePageToIconURL, homePagesWithNoIconURL] {
					do {
						logger.info("Removing cache file: \(tempItem.absoluteString)")
						try FileManager.default.removeItem(at: tempItem)
					} catch {
						logger.error("Could not delete cache file: \(error.localizedDescription)")
					}
				}

				AppDefaults.shared.lastImageCacheFlushDate = Date()
			}
		}
	}
}

private extension CacheCleaner {

	/// One-time purge of image caches so that oversized cached images
	/// are replaced with properly resized versions on re-download.
	static func purgeImageCachesForResizingIfNeeded() {
		guard !UserDefaults.standard.bool(forKey: didPurgeImageCachesForResizingKey) else {
			return
		}

		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let foldersToRemove = [
			cacheDir.appendingPathComponent("Favicons"),
			cacheDir.appendingPathComponent("Images"),
			cacheDir.appendingPathComponent("FeedIcons")
		]

		for folder in foldersToRemove {
			do {
				try FileManager.default.removeItem(at: folder)
				logger.info("Purged image cache folder: \(folder.lastPathComponent, privacy: .public)")
			} catch {
				// Folder may not exist yet — that's fine
			}
		}

		UserDefaults.standard.set(true, forKey: didPurgeImageCachesForResizingKey)
	}
}
