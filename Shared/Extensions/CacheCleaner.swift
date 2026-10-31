//
//  CacheCleaner.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import os

struct CacheCleaner {

	static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "CacheCleaner")

	private static let didRemoveFoldersReplacedByDownloadedImageCacheKey = "didRemoveFoldersReplacedByDownloadedImageCache-2026-10-27"

	static func purgeIfNecessary() {
		removeFoldersReplacedByDownloadedImageCacheIfNeeded()
	}
}

private extension CacheCleaner {

	/// One-time removal of the image folders that DownloadedImageCache’s DownloadedImages folder replaces.
	/// Off the main thread, since a large old folder can take a while to delete.
	static func removeFoldersReplacedByDownloadedImageCacheIfNeeded() {
		guard !UserDefaults.standard.bool(forKey: didRemoveFoldersReplacedByDownloadedImageCacheKey) else {
			return
		}

		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let foldersToRemove = [
			cacheDir.appendingPathComponent("Favicons"),
			cacheDir.appendingPathComponent("Images"),
			cacheDir.appendingPathComponent("FeedIcons"),
			cacheDir.appendingPathComponent("Thumbnails"),
			cacheDir.appendingPathComponent("LargeThumbnails")
		]

		Task.detached(priority: .utility) {
			for folder in foldersToRemove {
				do {
					try FileManager.default.removeItem(at: folder)
					logger.info("Removed image folder replaced by DownloadedImageCache: \(folder.lastPathComponent, privacy: .public)")
				} catch {
					// Folder may not exist — that's fine
				}
			}

			UserDefaults.standard.set(true, forKey: didRemoveFoldersReplacedByDownloadedImageCacheKey)
		}
	}
}
