//
//  FaviconDownloader.swift
//  Images
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os
import CoreServices
import Articles
import Account
import RSCore
import RSWeb
import HTMLMetadata
import UniformTypeIdentifiers

extension Notification.Name {

	public static let FaviconDidBecomeAvailable = Notification.Name("FaviconDidBecomeAvailableNotification") // userInfo key: FaviconDownloader.UserInfoKey.faviconURL
}

@MainActor public final class FaviconDownloader {
	public static let shared = FaviconDownloader()

	nonisolated static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FaviconDownloader")

	private let folder: String
	private let diskCache: BinaryDiskCache
	private var singleFaviconDownloaderCache = [String: SingleFaviconDownloader]() // faviconURL: SingleFaviconDownloader
	private var remainingFaviconURLs = [String: ArraySlice<String>]() // homePageURL: array of faviconURLs that haven't been checked yet
	private var currentHomePageHasOnlyFaviconICO = false

	private let queue: DispatchQueue
	private var cache = [Feed: IconImage]() // faviconURL: RSImage

	public struct UserInfoKey {
		public static let faviconURL = "faviconURL"
	}

	init() {
		let folderURL = AppConfig.cacheSubfolder(named: "Favicons")
		let folder = folderURL.path
		self.folder = folder
		self.diskCache = BinaryDiskCache(folder: folder)
		self.queue = DispatchQueue(label: "FaviconDownloader serial queue - \(folder)")

		NotificationCenter.default.addObserver(self, selector: #selector(didLoadFavicon(_:)), name: .DidLoadFavicon, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(htmlMetadataIsAvailable(_:)), name: .htmlMetadataAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
	}

	// MARK: - API

	@objc func handleLowMemory(_ notification: Notification) {
		cache.removeAll()
		singleFaviconDownloaderCache.removeAll()
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		cache.removeAll()
		singleFaviconDownloaderCache.removeAll()
	}

	public func favicon(for feed: Feed) -> IconImage? {
		assert(Thread.isMainThread)

		if shouldSkipDownloadingFavicon(feed: feed) {
			return nil
		}

		var homePageURL = feed.homePageURL
		if let faviconURL = feed.faviconURL {
			return favicon(with: faviconURL, homePageURL: homePageURL)
		}

		if homePageURL == nil {
			// Base homePageURL off feedURL if needed. Won’t always be accurate, but is good enough.
			if let feedURL = URL(string: feed.url), let scheme = feedURL.scheme, let host = feedURL.host {
				homePageURL = scheme + "://" + host + "/"
			}
		}
		if let homePageURL = homePageURL {
			return favicon(withHomePageURL: homePageURL)
		}

		return nil
	}

	public func faviconAsIcon(for feed: Feed) -> IconImage? {

		if let image = cache[feed] {
			return image
		}

		if let iconImage = favicon(for: feed) {
			cache[feed] = iconImage
			return iconImage
		}

		return nil
	}

	/// Returns the in-memory favicon for `feed` without triggering a download.
	public func cachedFaviconAsIcon(for feed: Feed) -> IconImage? {
		if let image = cache[feed] {
			return image
		}
		guard let faviconURL = cachedFaviconURL(for: feed) else {
			return nil
		}
		guard let iconImage = singleFaviconDownloaderCache[faviconURL]?.iconImage else {
			return nil
		}
		cache[feed] = iconImage
		return iconImage
	}

	/// The known favicon URL for `feed` (from feed settings or the home-page→favicon map), without
	/// triggering any download. Both lookups are in-memory, so this is cheap to call per row.
	public func cachedFaviconURL(for feed: Feed) -> String? {
		if let faviconURL = feed.faviconURL {
			return faviconURL
		}
		if let homePageURL = feed.homePageURL, let faviconURL = ImageMetadataDatabase.shared.faviconURL(forHomePageURL: homePageURL) {
			return faviconURL
		}
		return nil
	}

	public func favicon(with faviconURL: String, homePageURL: String?) -> IconImage? {
		if !faviconURL.hasPrefix("http://") && !faviconURL.hasPrefix("https://") {
			Self.logger.debug("Skipping non-http(s) URL: \(faviconURL)")
			return nil
		}
		if ImageMetadataDatabase.shared.recentlyFailed(url: faviconURL) {
			Self.logger.debug("Skipping recently-failed URL: \(faviconURL)")
			return nil
		}
		let downloader = faviconDownloader(withURL: faviconURL, homePageURL: homePageURL)
		return downloader.iconImage
	}

	public func favicon(withHomePageURL homePageURL: String) -> IconImage? {

		let url = homePageURL.normalizedURL

		if ImageMetadataDatabase.shared.homePageHasNoFavicon(url) {
			return nil
		}

		if let faviconURL = ImageMetadataDatabase.shared.faviconURL(forHomePageURL: url) {
			return favicon(with: faviconURL, homePageURL: url)
		}

		if let faviconURLs = findFaviconURLs(with: url) {
			// If the site explicitly specifies favicon.ico, it will appear twice.
			self.currentHomePageHasOnlyFaviconICO = faviconURLs.count == 1

			if let firstIconURL = faviconURLs.first {
				_ = self.favicon(with: firstIconURL, homePageURL: url)
				self.remainingFaviconURLs[url] = faviconURLs.dropFirst()
			}
		}

		return nil
	}

	// MARK: - Notifications

	@objc func didLoadFavicon(_ note: Notification) {

		guard let singleFaviconDownloader = note.object as? SingleFaviconDownloader else {
			return
		}

		// URL-level outcome runs before the homePageURL guard so we record it even when homePageURL is nil.
		if let error = singleFaviconDownloader.error {
			ImageMetadataDatabase.shared.recordFailure(url: singleFaviconDownloader.faviconURL, statusCode: error.statusCode)
		} else if singleFaviconDownloader.iconImage != nil {
			ImageMetadataDatabase.shared.clearFailure(url: singleFaviconDownloader.faviconURL)
		}

		guard let homePageURL = singleFaviconDownloader.homePageURL else {
			return
		}
		guard singleFaviconDownloader.iconImage != nil else {
			if let faviconURLs = remainingFaviconURLs[homePageURL] {
				if let nextIconURL = faviconURLs.first {
					_ = favicon(with: nextIconURL, homePageURL: singleFaviconDownloader.homePageURL)
					remainingFaviconURLs[homePageURL] = faviconURLs.dropFirst()
				} else {
					remainingFaviconURLs[homePageURL] = nil

					if currentHomePageHasOnlyFaviconICO {
						ImageMetadataDatabase.shared.saveHomePageFavicon(homePageURL: homePageURL, faviconURL: nil)
					}
				}
			}
			return
		}

		remainingFaviconURLs[homePageURL] = nil

		postFaviconDidBecomeAvailableNotification(singleFaviconDownloader.faviconURL)
	}

	@objc func htmlMetadataIsAvailable(_ note: Notification) {

		guard let url = note.userInfo?[HTMLMetadataUserInfoKey.url] as? String else {
			assertionFailure("Expected URL string in .htmlMetadataAvailable Notification userInfo.")
			return
		}

		Task { @MainActor in
			_ = favicon(withHomePageURL: url)
		}
	}
}

private extension FaviconDownloader {

	static let specialCasesToSkip = [SpecialCase.rachelByTheBayHostName, SpecialCase.openRSSOrgHostName]

	func shouldSkipDownloadingFavicon(feed: Feed) -> Bool {
		SpecialCase.urlStringContainSpecialCase(feed.url, Self.specialCasesToSkip)
	}

	static let localeForLowercasing = Locale(identifier: "en_US")

	func findFaviconURLs(with homePageURL: String) -> [String]? {

		guard let url = URL(string: homePageURL) else {
			return nil
		}
		guard let htmlMetadata = HTMLMetadataDownloader.shared.cachedMetadata(for: homePageURL) else {
			return nil
		}
		let faviconURLs = htmlMetadata.usableFaviconURLs() ?? [String]()

		guard let scheme = url.scheme, let host = url.host else {
			return faviconURLs.isEmpty ? nil : faviconURLs
		}

		let defaultFaviconURL = "\(scheme)://\(host)/favicon.ico".lowercased(with: FaviconDownloader.localeForLowercasing)
		return faviconURLs + [defaultFaviconURL]
	}

	func faviconDownloader(withURL faviconURL: String, homePageURL: String?) -> SingleFaviconDownloader {

		var firstTimeSeeingHomepageURL = false

		if let homePageURL, ImageMetadataDatabase.shared.faviconURL(forHomePageURL: homePageURL) == nil {
			ImageMetadataDatabase.shared.saveHomePageFavicon(homePageURL: homePageURL, faviconURL: faviconURL)
			firstTimeSeeingHomepageURL = true
		}

		if let downloader = singleFaviconDownloaderCache[faviconURL] {
			if firstTimeSeeingHomepageURL && !downloader.downloadFaviconIfNeeded() {
				// This is to handle the scenario where we have different homepages, but the same favicon.
				// This happens for Twitter and probably other sites like Blogger.  Because the favicon
				// is cached, we wouldn't send out a notification that it is now available unless we send
				// it here.
				postFaviconDidBecomeAvailableNotification(faviconURL)
			}
			return downloader
		}

		let downloader = SingleFaviconDownloader(faviconURL: faviconURL, homePageURL: homePageURL, diskCache: diskCache, queue: queue)
		singleFaviconDownloaderCache[faviconURL] = downloader
		return downloader
	}

	func postFaviconDidBecomeAvailableNotification(_ faviconURL: String) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = [UserInfoKey.faviconURL: faviconURL]
			NotificationCenter.default.post(name: .FaviconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}
}

private extension HTMLMetadataRecord {

	func usableFaviconURLs() -> [String]? {

		favicons.compactMap { favicon in
			shouldAllowFavicon(favicon) ? favicon.urlString : nil
		}
	}

	static let ignoredTypes = [UTType.svg]

	private func shouldAllowFavicon(_ favicon: HTMLMetadataRecord.Favicon) -> Bool {

		// Check mime type.
		if let mimeType = favicon.type, let utType = UTType(mimeType: mimeType) {
			if Self.ignoredTypes.contains(utType) {
				return false
			}
		}

		// Check file extension.
		if let urlString = favicon.urlString, let url = URL(string: urlString), let utType = UTType(filenameExtension: url.pathExtension) {
			if Self.ignoredTypes.contains(utType) {
				return false
			}
		}

		return true
	}
}
