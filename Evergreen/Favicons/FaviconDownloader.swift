//
//  FaviconDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import Data
import RSCore

extension Notification.Name {

	static let FaviconDidBecomeAvailable = Notification.Name("FaviconDidBecomeAvailableNotification") // userInfo key: FaviconDownloader.UserInfoKey.faviconURL
}

final class FaviconDownloader {

	private var seekingFaviconCache = [String: SeekingFavicon]() // homePageURL: SeekingFavicon
	private var singleFaviconDownloaderCache = [String: SingleFaviconDownloader]() // faviconURL: SingleFaviconDownloader
	private let folder: String
	private let diskCache: BinaryDiskCache
	private let queue: DispatchQueue

	struct UserInfoKey {
		static let faviconURL = "faviconURL"
	}

	init(folder: String) {

		self.folder = folder
		self.diskCache = BinaryDiskCache(folder: folder)
		self.queue = DispatchQueue(label: "FaviconDownloader serial queue - \(folder)")

		NotificationCenter.default.addObserver(self, selector: #selector(seekingFaviconDidSeek(_:)), name: .SeekingFaviconSeekDidComplete, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(didLoadFavicon(_:)), name: .DidLoadFavicon, object: nil)
	}

	// MARK: - API

	func favicon(for feed: Feed) -> NSImage? {

		assert(Thread.isMainThread)

		if let faviconURL = feed.faviconURL {
			return favicon(with: faviconURL)
		}

		guard let homePageURL = feed.homePageURL else {
			return nil
		}
		return favicon(withHomePageURL: homePageURL)
	}

	func favicon(with faviconURL: String) -> NSImage? {

		let downloader = faviconDownloader(withURL: faviconURL)
		return downloader.image
	}

	func favicon(withHomePageURL homePageURL: String) -> NSImage? {

		guard let seekingFavicon = seekingFavicon(with: homePageURL) else {
			return nil
		}
		return favicon(withSeekingFavicon: seekingFavicon)
	}

	// MARK: - Notifications

	@objc func seekingFaviconDidSeek(_ note: Notification) {

		guard let seekingFavicon = note.object as? SeekingFavicon else {
			return
		}
		favicon(withSeekingFavicon: seekingFavicon)
	}

	@objc func didLoadFavicon(_ note: Notification) {

		guard let singleFaviconDownloader = note.object as? SingleFaviconDownloader else {
			return
		}
		guard let _ = singleFaviconDownloader.image else {
			return
		}

		postFaviconDidBecomeAvailableNotification(singleFaviconDownloader.faviconURL)
	}
}

private extension FaviconDownloader {

	@discardableResult
	func favicon(withSeekingFavicon seekingFavicon: SeekingFavicon) -> NSImage? {

		guard let faviconURL = seekingFavicon.faviconURL else {
			return nil
		}
		return favicon(with: faviconURL)
	}

	func faviconDownloader(withURL faviconURL: String) -> SingleFaviconDownloader {

		if let downloader = singleFaviconDownloaderCache[faviconURL] {
			downloader.downloadFaviconIfNeeded()
			return downloader
		}

		let downloader = SingleFaviconDownloader(faviconURL: faviconURL, diskCache: diskCache, queue: queue)
		singleFaviconDownloaderCache[faviconURL] = downloader
		return downloader
	}

	func seekingFavicon(with homePageURL: String) -> SeekingFavicon? {

		if let seekingFavicon = seekingFaviconCache[homePageURL] {
			return seekingFavicon
		}

		guard let seekingFavicon = SeekingFavicon(homePageURL: homePageURL) else {
			return nil
		}
		seekingFaviconCache[homePageURL] = seekingFavicon
		return seekingFavicon
	}

	func postFaviconDidBecomeAvailableNotification(_ faviconURL: String) {

		let userInfo: [AnyHashable: Any] = [UserInfoKey.faviconURL: faviconURL]
		NotificationCenter.default.post(name: .FaviconDidBecomeAvailable, object: self, userInfo: userInfo)
	}
}
