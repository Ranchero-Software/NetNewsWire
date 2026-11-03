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

	nonisolated static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "FaviconDownloader")

	private var singleFaviconDownloaderCache = [String: SingleFaviconDownloader]() // faviconURL: SingleFaviconDownloader
	private var searches = [String: FaviconSearch]() // homePageURL: search through its favicon URLs
	private var homePagesAwaitingMetadataForSearch = Set<String>()
	private var homePagesCheckedForNewFavicon = Set<String>()
	private var homePagesWithTransientSearchFailure = Set<String>()

	private var cache = [Feed: IconImage]()

	public struct UserInfoKey {
		public static let faviconURL = "faviconURL"
	}

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(didLoadFavicon(_:)), name: .DidLoadFavicon, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(htmlMetadataIsAvailable(_:)), name: .htmlMetadataAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleDownloadedImageDidChange(_:)), name: .downloadedImageDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleNetworkStatusDidChange(_:)), name: .networkStatusDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleFeedSettingDidChange(_:)), name: .feedSettingDidChange, object: nil)
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

		if let faviconURL = usableDeclaredFaviconURL(for: feed) {
			return favicon(with: faviconURL, homePageURL: feed.homePageURL)
		}
		if let homePageURL = faviconHomePageURL(for: feed) {
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
	/// The home page is the same one `favicon(for:)` saves under.
	public func cachedFaviconURL(for feed: Feed) -> String? {
		if let faviconURL = usableDeclaredFaviconURL(for: feed) {
			return faviconURL
		}
		if let homePageURL = faviconHomePageURL(for: feed), let faviconURL = ImageDatabase.shared.faviconURL(forHomePageURL: homePageURL) {
			return faviconURL
		}
		return nil
	}

	public func favicon(with faviconURL: String, homePageURL: String?) -> IconImage? {
		guard canAttemptDownload(faviconURL) else {
			return nil
		}
		let downloader = faviconDownloader(withURL: faviconURL, homePageURL: homePageURL)
		return downloader.iconImage
	}

	public func favicon(withHomePageURL homePageURL: String) -> IconImage? {

		let url = homePageURL.normalizedURL

		if ImageDatabase.shared.homePageHasNoFavicon(url) {
			return nil
		}

		// A saved favicon that keeps failing is searched for again, in case the site moved it.
		if let faviconURL = ImageDatabase.shared.faviconURL(forHomePageURL: url), !ImageDatabase.shared.recentlyFailed(url: faviconURL) {
			checkForNewFaviconURL(homePageURL: url, savedFaviconURL: faviconURL)
			return favicon(with: faviconURL, homePageURL: url)
		}

		searchForFavicon(homePageURL: url)
		return nil
	}

	// MARK: - Notifications

	/// Every home page searching with this favicon URL moves on: to saving it, or to its next candidate.
	///
	/// When a saved favicon URL returns something that isn’t an image, the site may have moved its favicon,
	/// so its home pages are searched again. The saved URL stays until a search finds another one,
	/// so a captive portal can’t clear it.
	@objc func didLoadFavicon(_ note: Notification) {

		guard let singleFaviconDownloader = note.object as? SingleFaviconDownloader else {
			return
		}
		let faviconURL = singleFaviconDownloader.faviconURL
		let foundFavicon = singleFaviconDownloader.iconImage != nil
		if foundFavicon {
			postFaviconDidBecomeAvailableNotification(faviconURL)
		}

		let homePageURLs = searches.filter { $0.value.faviconURL == faviconURL }.keys
		for homePageURL in homePageURLs {
			if foundFavicon {
				saveFoundFavicon(faviconURL, homePageURL: homePageURL)
			} else {
				if singleFaviconDownloader.lastFailureWasTransient {
					searches[homePageURL]?.hadTransientFailure = true
				}
				downloadNextFavicon(forHomePageURL: homePageURL)
			}
		}

		if !foundFavicon && singleFaviconDownloader.lastFailureWasNotAnImage {
			for homePageURL in ImageDatabase.shared.homePageURLs(withFaviconURL: faviconURL) {
				searchForFavicon(homePageURL: homePageURL)
			}
		}
	}

	/// A new downloader reads the new copy and posts `.DidLoadFavicon`, which leads to `.FaviconDidBecomeAvailable`.
	@objc func handleDownloadedImageDidChange(_ notification: Notification) {
		guard let faviconURL = notification.userInfo?[DownloadedImageCache.urlKey] as? String, let downloader = singleFaviconDownloaderCache[faviconURL] else {
			return
		}
		let feeds = cache.keys.filter { cachedFaviconURL(for: $0) == faviconURL }
		for feed in feeds {
			cache[feed] = nil
		}
		singleFaviconDownloaderCache[faviconURL] = SingleFaviconDownloader(faviconURL: faviconURL, homePageURL: downloader.homePageURL)
	}

	/// Waits for transient failures may have just ended, so those favicons and searches are tried again.
	/// Runs after `DownloadedImageCache` ends those waits, which it does on this notification too.
	@objc func handleNetworkStatusDidChange(_ notification: Notification) {
		guard NetworkMonitor.shared.isConnected else {
			return
		}
		Task { @MainActor in
			for downloader in singleFaviconDownloaderCache.values where downloader.lastFailureWasTransient {
				downloader.downloadFaviconIfNeeded()
			}
			let homePageURLs = homePagesWithTransientSearchFailure
			homePagesWithTransientSearchFailure.removeAll()
			for homePageURL in homePageURLs {
				searchForFavicon(homePageURL: homePageURL)
			}
		}
	}

	/// A favicon already in memory posts nothing when it loads, so it’s posted here.
	@objc func handleFeedSettingDidChange(_ notification: Notification) {
		guard let feed = notification.object as? Feed, let key = notification.userInfo?[Feed.SettingUserInfoKey] as? Feed.SettingKey else {
			return
		}
		guard key == .faviconURL || key == .homePageURL else {
			return
		}
		cache[feed] = nil
		if faviconAsIcon(for: feed) != nil, let faviconURL = cachedFaviconURL(for: feed) {
			postFaviconDidBecomeAvailableNotification(faviconURL)
		}
	}

	@objc func htmlMetadataIsAvailable(_ note: Notification) {

		guard let url = note.userInfo?[HTMLMetadataUserInfoKey.url] as? String else {
			assertionFailure("Expected URL string in .htmlMetadataAvailable Notification userInfo.")
			return
		}

		Task { @MainActor in
			// New metadata may name a different favicon.
			homePagesCheckedForNewFavicon.remove(url)
			if homePagesAwaitingMetadataForSearch.remove(url) != nil {
				searchForFavicon(homePageURL: url)
			} else {
				_ = favicon(withHomePageURL: url)
			}
		}
	}
}

private extension FaviconDownloader {

	static let specialCasesToSkip = [SpecialCase.rachelByTheBayHostName, SpecialCase.openRSSOrgHostName]

	/// A home page’s favicon URLs are tried in order until one works.
	struct FaviconSearch {
		var remainingFaviconURLs: ArraySlice<String>
		var faviconURL: String? // Being downloaded
		var hadTransientFailure = false
		/// A search for a better favicon than the saved one, which keeps working if none is found.
		var keepsSavedFavicon = false
	}

	func shouldSkipDownloadingFavicon(feed: Feed) -> Bool {
		SpecialCase.urlStringContainSpecialCase(feed.url, Self.specialCasesToSkip)
	}

	/// The favicon URL the feed declares, unless it recently failed or isn’t an image,
	/// in which case the home page’s favicon is used instead.
	/// Called per row, so it doesn’t log the way `canAttemptDownload` does.
	func usableDeclaredFaviconURL(for feed: Feed) -> String? {
		guard let faviconURL = feed.faviconURL, faviconURL.hasPrefix("http://") || faviconURL.hasPrefix("https://"), !ImageDatabase.shared.recentlyFailed(url: faviconURL) else {
			return nil
		}
		if let downloader = singleFaviconDownloaderCache[faviconURL], downloader.lastFailureWasNotAnImage {
			return nil
		}
		return faviconURL
	}

	/// The home page that favicons are saved under: the feed’s home page, or else the feed URL’s scheme and host.
	func faviconHomePageURL(for feed: Feed) -> String? {
		if let homePageURL = feed.homePageURL {
			return homePageURL.normalizedURL
		}
		// Won’t always be the real home page, but is good enough.
		guard let feedURL = URL(string: feed.url), let scheme = feedURL.scheme, let host = feedURL.host else {
			return nil
		}
		return (scheme + "://" + host + "/").normalizedURL
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

	/// Without the home page’s metadata in memory, the search starts when `.htmlMetadataAvailable` arrives.
	func searchForFavicon(homePageURL: String) {
		guard searches[homePageURL] == nil else {
			return
		}
		guard let faviconURLs = findFaviconURLs(with: homePageURL) else {
			homePagesAwaitingMetadataForSearch.insert(homePageURL)
			return
		}
		searches[homePageURL] = FaviconSearch(remainingFaviconURLs: faviconURLs[...])
		downloadNextFavicon(forHomePageURL: homePageURL)
	}

	/// The saved favicon keeps working after a site adds or moves its favicon, so once per session,
	/// and again when the home page’s metadata arrives, the candidates ahead of the saved one are tried.
	func checkForNewFaviconURL(homePageURL: String, savedFaviconURL: String) {
		guard !homePagesCheckedForNewFavicon.contains(homePageURL), searches[homePageURL] == nil else {
			return
		}
		homePagesCheckedForNewFavicon.insert(homePageURL)
		guard let faviconURLs = findFaviconURLs(with: homePageURL) else {
			return
		}
		let betterFaviconURLs = faviconURLs.prefix { $0 != savedFaviconURL }
		guard !betterFaviconURLs.isEmpty else {
			return
		}
		searches[homePageURL] = FaviconSearch(remainingFaviconURLs: betterFaviconURLs, keepsSavedFavicon: true)
		downloadNextFavicon(forHomePageURL: homePageURL)
	}

	func canAttemptDownload(_ faviconURL: String) -> Bool {
		if !faviconURL.hasPrefix("http://") && !faviconURL.hasPrefix("https://") {
			Self.logger.debug("Skipping non-http(s) URL: \(faviconURL)")
			return false
		}
		if ImageDatabase.shared.recentlyFailed(url: faviconURL) {
			Self.logger.debug("Skipping recently-failed URL: \(faviconURL)")
			return false
		}
		return true
	}

	/// A skipped candidate advances to the next one — otherwise the search
	/// would stall and the remaining candidates would never be tried.
	/// <https://github.com/Ranchero-Software/NetNewsWire/issues/4868>
	///
	/// Without a transient failure, a search that runs out of candidates saves that the home page has no favicon.
	func downloadNextFavicon(forHomePageURL homePageURL: String) {
		while var search = searches[homePageURL], let faviconURL = search.remainingFaviconURLs.first {
			search.remainingFaviconURLs = search.remainingFaviconURLs.dropFirst()
			search.faviconURL = nil
			searches[homePageURL] = search
			guard canAttemptDownload(faviconURL) else {
				continue
			}

			let downloader = faviconDownloader(withURL: faviconURL, homePageURL: homePageURL)
			if downloader.iconImage != nil {
				// Already downloaded for another home page, such as one on the same site, so no `.DidLoadFavicon` is coming.
				saveFoundFavicon(faviconURL, homePageURL: homePageURL)
				postFaviconDidBecomeAvailableNotification(faviconURL)
				return
			}
			if downloader.isFinding {
				searches[homePageURL]?.faviconURL = faviconURL
				return
			}
			// Failed earlier in this session, and isn’t due to be tried again yet.
			if downloader.lastFailureWasTransient {
				searches[homePageURL]?.hadTransientFailure = true
			}
		}

		guard let search = searches.removeValue(forKey: homePageURL) else {
			return
		}
		if search.hadTransientFailure {
			homePagesWithTransientSearchFailure.insert(homePageURL)
		} else if !search.keepsSavedFavicon {
			ImageDatabase.shared.saveHomePageFavicon(homePageURL: homePageURL, faviconURL: nil)
		}
	}

	/// Feeds showing the previous favicon get the new one on their next lookup.
	func saveFoundFavicon(_ faviconURL: String, homePageURL: String) {
		searches[homePageURL] = nil
		ImageDatabase.shared.saveHomePageFavicon(homePageURL: homePageURL, faviconURL: faviconURL)
		cache = cache.filter { faviconHomePageURL(for: $0.key) != homePageURL }
	}

	/// A cached downloader without an image tries again if its last attempt was a while ago.
	func faviconDownloader(withURL faviconURL: String, homePageURL: String?) -> SingleFaviconDownloader {
		if let downloader = singleFaviconDownloaderCache[faviconURL] {
			downloader.downloadFaviconIfNeeded()
			return downloader
		}

		let downloader = SingleFaviconDownloader(faviconURL: faviconURL, homePageURL: homePageURL)
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

		// Only http(s) — a data: or other non-web URL can't be downloaded as a favicon.
		guard let urlString = favicon.urlString,
			  urlString.hasPrefix("http://") || urlString.hasPrefix("https://") else {
			return false
		}

		// Check mime type.
		if let mimeType = favicon.type, let utType = UTType(mimeType: mimeType) {
			if Self.ignoredTypes.contains(utType) {
				return false
			}
		}

		// Check file extension.
		if let url = URL(string: urlString), let utType = UTType(filenameExtension: url.pathExtension) {
			if Self.ignoredTypes.contains(utType) {
				return false
			}
		}

		return true
	}
}
