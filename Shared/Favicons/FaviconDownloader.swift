//
//  FaviconDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import CoreServices
import UniformTypeIdentifiers
import os
import Articles
import Account
import RSCore
import RSWeb
import Parser

extension Notification.Name {

	static let FaviconDidBecomeAvailable = Notification.Name("FaviconDidBecomeAvailableNotification") // userInfo key: FaviconDownloader.UserInfoKey.faviconURL
}

final class FaviconDownloader {

	private static let saveQueue = CoalescingQueue(name: "Cache Save Queue", interval: 1.0)

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FaviconDownloader")
	private static let debugLoggingEnabled = false

	private let folder: String
	private let diskCache: BinaryDiskCache
	private var singleFaviconDownloaderCache = [String: SingleFaviconDownloader]() // faviconURL: SingleFaviconDownloader
	private var remainingFaviconURLs = [String: ArraySlice<String>]() // homePageURL: array of faviconURLs that haven't been checked yet
	private var currentHomePageHasOnlyFaviconICO = false

	private var homePageToFaviconURLCache = [String: String]() // homePageURL: faviconURL
	private var homePageToFaviconURLCachePath: String
	private var homePageToFaviconURLCacheDirty = false {
		didSet {
			queueSaveHomePageToFaviconURLCacheIfNeeded()
		}
	}

	private var homePageURLsWithNoFaviconURLCache = Set<String>()
	private var homePageURLsWithNoFaviconURLCachePath: String
	private var homePageURLsWithNoFaviconURLCacheDirty = false {
		didSet {
			queueSaveHomePageURLsWithNoFaviconURLCacheIfNeeded()
		}
	}

	private let queue: DispatchQueue
	private var cache = [Feed: IconImage]() // faviconURL: RSImage

	struct UserInfoKey {
		static let faviconURL = "faviconURL"
	}

	init(folder: String) {

		self.folder = folder
		self.diskCache = BinaryDiskCache(folder: folder)
		self.queue = DispatchQueue(label: "FaviconDownloader serial queue - \(folder)")

		self.homePageToFaviconURLCachePath = (folder as NSString).appendingPathComponent("HomePageToFaviconURLCache.plist")
		self.homePageURLsWithNoFaviconURLCachePath = (folder as NSString).appendingPathComponent("HomePageURLsWithNoFaviconURLCache.plist")
		loadHomePageToFaviconURLCache()
		loadHomePageURLsWithNoFaviconURLCache()

		NotificationCenter.default.addObserver(self, selector: #selector(didLoadFavicon(_:)), name: .DidLoadFavicon, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(htmlMetadataIsAvailable(_:)), name: .htmlMetadataAvailable, object: nil)
	}

	// MARK: - API

	func resetCache() {
		cache = [Feed: IconImage]()
	}

	func favicon(for feed: Feed) -> IconImage? {

		assert(Thread.isMainThread)

		if Self.debugLoggingEnabled {
			Self.logger.debug("FaviconDownloader: favicon for feed \(feed.url)")
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

	func faviconAsIcon(for feed: Feed) -> IconImage? {

		if let image = cache[feed] {
			return image
		}

		if let iconImage = favicon(for: feed), let imageData = iconImage.image.dataRepresentation() {
			if let scaledImage = RSImage.scaledForIcon(imageData) {
				let scaledIconImage = IconImage(scaledImage)
				cache[feed] = scaledIconImage
				return scaledIconImage
			}
		}

		return nil
	}

	func favicon(with faviconURL: String, homePageURL: String?) -> IconImage? {

		if Self.debugLoggingEnabled {
			Self.logger.debug("FaviconDownloader: downloading favicon with favicon URL \(faviconURL) and home page URL \(homePageURL ?? "()")")
		}

		let downloader = faviconDownloader(withURL: faviconURL, homePageURL: homePageURL)
		return downloader.iconImage
	}

	func favicon(withHomePageURL homePageURL: String) -> IconImage? {

		let url = homePageURL.normalizedURL

		if let url = URL(string: homePageURL) {
			if ImageUtilities.shouldUseNNWFeedIcon(with: url) {
				return IconImage.nnwFeedIcon
			}
		}

		if Self.debugLoggingEnabled {
			Self.logger.debug("FaviconDownloader: downloading favicon for home page URL \(url)")
		}

		if homePageURLsWithNoFaviconURLCache.contains(url) {
			if Self.debugLoggingEnabled {
				Self.logger.debug("FaviconDownloader: home page URL \(url) is known to have no favicon")
			}
			return nil
		}

		if let faviconURL = homePageToFaviconURLCache[url] {
			if Self.debugLoggingEnabled {
				Self.logger.debug("FaviconDownloader: home page URL \(url) has cached favicon URL \(faviconURL)")
			}
			return favicon(with: faviconURL, homePageURL: url)
		}

		if let faviconURLs = findFaviconURLs(with: url) {

			if Self.debugLoggingEnabled {
				Self.logger.debug("FaviconDownloader: found favicon URLs for home page URL \(url): \(faviconURLs)")
			}

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
			assertionFailure("Expected singleFaviconDownloader as note.object for .DidLoadFavicon notification.")
			return
		}
		guard let homePageURL = singleFaviconDownloader.homePageURL else {
			return
		}

		if Self.debugLoggingEnabled {
			Self.logger.debug("FaviconDownloader: received didLoadFavicon notification for home page URL \(homePageURL)")
		}

		if singleFaviconDownloader.iconImage == nil {
			if let faviconURLs = remainingFaviconURLs[homePageURL] {
				if let nextIconURL = faviconURLs.first {
					_ = favicon(with: nextIconURL, homePageURL: singleFaviconDownloader.homePageURL)
					remainingFaviconURLs[homePageURL] = faviconURLs.dropFirst()
				} else {
					remainingFaviconURLs[homePageURL] = nil

					if currentHomePageHasOnlyFaviconICO {
						self.homePageURLsWithNoFaviconURLCache.insert(homePageURL)
						self.homePageURLsWithNoFaviconURLCacheDirty = true
					}
				}
			}
			return
		}

		remainingFaviconURLs[homePageURL] = nil

		postFaviconDidBecomeAvailableNotification(singleFaviconDownloader.faviconURL)
	}

	@objc func htmlMetadataIsAvailable(_ note: Notification) {

		guard let url = note.userInfo?[HTMLMetadataCache.UserInfoKey.url] as? String else {
			assertionFailure("Expected URL string in .htmlMetadataAvailable Notification userInfo.")
			return
		}

		if Self.debugLoggingEnabled {
			Self.logger.debug("FaviconDownloader: received .htmlMetadataAvailable notification for URL \(url)")
		}

		Task { @MainActor in
			// This will fetch the favicon (if possible) and post a .FaviconDidBecomeAvailable Notification.
			_ = favicon(withHomePageURL: url)
		}
	}

	@objc func saveHomePageToFaviconURLCacheIfNeeded() {
		if homePageToFaviconURLCacheDirty {
			saveHomePageToFaviconURLCache()
		}
	}

	@objc func saveHomePageURLsWithNoFaviconURLCacheIfNeeded() {
		if homePageURLsWithNoFaviconURLCacheDirty {
			saveHomePageURLsWithNoFaviconURLCache()
		}
	}
}

private extension FaviconDownloader {

	static let localeForLowercasing = Locale(identifier: "en_US")

	func findFaviconURLs(with homePageURL: String) -> [String]? {

		if Self.debugLoggingEnabled {
			Self.logger.debug("FaviconDownloader: finding favicon URLs for home page URL \(homePageURL)")
		}

		guard let url = URL(string: homePageURL) else {
			return nil
		}
		guard let htmlMetadata = HTMLMetadataDownloader.shared.cachedMetadata(for: homePageURL) else {
			if Self.debugLoggingEnabled {
				Self.logger.debug("FaviconDownloader: skipping finding favicon URLs for home page URL \(homePageURL) because no HTMLMetadata is available yet")
			}
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

		if let homePageURL = homePageURL, self.homePageToFaviconURLCache[homePageURL] == nil {
			self.homePageToFaviconURLCache[homePageURL] = faviconURL
			self.homePageToFaviconURLCacheDirty = true
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

			if Self.debugLoggingEnabled {
				Self.logger.debug("FaviconDownloader: posting favicon available notification for favicon URL \(faviconURL)")
			}

			let userInfo: [AnyHashable: Any] = [UserInfoKey.faviconURL: faviconURL]
			NotificationCenter.default.post(name: .FaviconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}

	func loadHomePageToFaviconURLCache() {
		let url = URL(fileURLWithPath: homePageToFaviconURLCachePath)
		guard let data = try? Data(contentsOf: url) else {
			return
		}
		let decoder = PropertyListDecoder()
		homePageToFaviconURLCache = (try? decoder.decode([String: String].self, from: data)) ?? [String: String]()
	}

	func loadHomePageURLsWithNoFaviconURLCache() {
		let url = URL(fileURLWithPath: homePageURLsWithNoFaviconURLCachePath)
		guard let data = try? Data(contentsOf: url) else {
			return
		}
		let decoder = PropertyListDecoder()
		let decoded = (try? decoder.decode([String].self, from: data)) ?? [String]()
		homePageURLsWithNoFaviconURLCache = Set(decoded)
	}

	func queueSaveHomePageToFaviconURLCacheIfNeeded() {
		FaviconDownloader.saveQueue.add(self, #selector(saveHomePageToFaviconURLCacheIfNeeded))
	}

	func queueSaveHomePageURLsWithNoFaviconURLCacheIfNeeded() {
		FaviconDownloader.saveQueue.add(self, #selector(saveHomePageURLsWithNoFaviconURLCacheIfNeeded))
	}

	func saveHomePageToFaviconURLCache() {

		if Self.debugLoggingEnabled {
			Self.logger.debug("FaviconDownloader: saving homePageToFaviconURLCache")
		}

		homePageToFaviconURLCacheDirty = false

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let url = URL(fileURLWithPath: homePageToFaviconURLCachePath)
		do {
			let data = try encoder.encode(homePageToFaviconURLCache)
			try data.write(to: url)
		} catch {
			assertionFailure(error.localizedDescription)
		}
	}

	func saveHomePageURLsWithNoFaviconURLCache() {

		if Self.debugLoggingEnabled {
			Self.logger.debug("FaviconDownloader: saving homePageURLsWithNoFaviconURLCache")
		}

		homePageURLsWithNoFaviconURLCacheDirty = false

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let url = URL(fileURLWithPath: homePageURLsWithNoFaviconURLCachePath)
		do {
			let data = try encoder.encode(Array(homePageURLsWithNoFaviconURLCache))
			try data.write(to: url)
		} catch {
			assertionFailure(error.localizedDescription)
		}
	}
}

private extension HTMLMetadata {

	func usableFaviconURLs() -> [String]? {

		favicons?.compactMap { favicon in
			shouldAllowFavicon(favicon) ? favicon.urlString : nil
		}
	}

	static let ignoredTypes = [UTType.svg]

	private func shouldAllowFavicon(_ favicon: HTMLMetadataFavicon) -> Bool {

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
