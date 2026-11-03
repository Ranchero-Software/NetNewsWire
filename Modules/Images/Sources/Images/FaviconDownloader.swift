//
//  FaviconDownloader.swift
//  Images
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os
import Articles
import Account
import RSCore
import RSWeb
import HTMLMetadata
import ActivityLog
import UniformTypeIdentifiers

extension Notification.Name {
	/// Posted when a favicon loads. userInfo key: `FaviconDownloader.feedsKey` (`Set<Feed>`, the feeds that looked it up and use it).
	public static let faviconDidChange = Notification.Name("FaviconDidChange")
}

/// Gets a feed’s favicon: the one the feed specifies, or else the first that works of the favicons its home page’s metadata specifies, then `/favicon.ico`.
@MainActor public final class FaviconDownloader {

	public static let shared = FaviconDownloader()
	public static let feedsKey = "feeds"

	nonisolated static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "FaviconDownloader")

	private var searches = [String: FaviconSearch]() // homePageURL: search through its favicon URLs
	private var homePagesLookedUp = Set<String>()
	private var homePagesAwaitingMetadataForSearch = Set<String>()
	private var homePagesCheckedForNewFavicon = Set<String>()
	private var homePagesWithTransientSearchFailure = Set<String>()
	private var feeds = Set<Feed>() // Every feed that looked up its favicon, so its favicon’s arrival is posted
	private var faviconURLs = Set<String>() // Every favicon URL looked up
	private var faviconURLsThatAreNotImages = Set<String>()

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleIconImageDidBecomeAvailable(_:)), name: .iconImageDidBecomeAvailable, object: IconImageDownloader.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(handleIconImageDownloadDidFail(_:)), name: .iconImageDownloadDidFail, object: IconImageDownloader.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(handleHTMLMetadataAvailable(_:)), name: .htmlMetadataAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleNetworkStatusDidChange(_:)), name: .networkStatusDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleFeedSettingDidChange(_:)), name: .feedSettingDidChange, object: nil)
	}

	// MARK: - API

	/// Loading while a search through the home page’s favicons is downloading one.
	public func favicon(for feed: Feed) -> IconLookup {
		if shouldSkipDownloadingFavicon(feed: feed) {
			return .unavailable
		}
		feeds.insert(feed)
		if let faviconURL = usableDeclaredFaviconURL(for: feed) {
			return iconImage(for: faviconURL, homePageURL: feed.homePageURL)
		}
		guard let homePageURL = faviconHomePageURL(for: feed) else {
			return .unavailable
		}
		return favicon(forHomePageURL: homePageURL)
	}

	// MARK: - Notifications

	/// Every home page searching with this favicon URL saves it.
	@objc func handleIconImageDidBecomeAvailable(_ notification: Notification) {
		guard let faviconURL = notification.userInfo?[IconImageDownloader.urlKey] as? String, faviconURLs.contains(faviconURL) else {
			return
		}
		faviconURLsThatAreNotImages.remove(faviconURL)
		for homePageURL in homePageURLsSearching(with: faviconURL) {
			saveFoundFavicon(faviconURL, homePageURL: homePageURL)
		}
		postFaviconDidChange(faviconURL)
	}

	/// Every home page searching with this favicon URL moves on to its next candidate.
	///
	/// When a saved favicon URL returns something that isn’t an image, the site may have moved its favicon,
	/// so its home pages are searched again. The saved URL stays until a search finds another one,
	/// so a captive portal can’t clear it.
	@objc func handleIconImageDownloadDidFail(_ notification: Notification) {
		guard let faviconURL = notification.userInfo?[IconImageDownloader.urlKey] as? String, faviconURLs.contains(faviconURL) else {
			return
		}
		let error = notification.userInfo?[IconImageDownloader.errorKey] as? ImageDownloadError

		for homePageURL in homePageURLsSearching(with: faviconURL) {
			if error?.isTransient == true {
				searches[homePageURL]?.hadTransientFailure = true
			}
			downloadNextFavicon(forHomePageURL: homePageURL)
		}

		if error?.decodingFailed == true {
			faviconURLsThatAreNotImages.insert(faviconURL)
			for homePageURL in ImageDatabase.shared.homePageURLs(withFaviconURL: faviconURL) {
				searchForFavicon(homePageURL: homePageURL)
			}
		}
	}

	/// Waits for transient failures may have just ended, so searches that had one are tried again.
	/// `IconImageDownloader` tries favicons that failed transiently again on this notification too.
	@objc func handleNetworkStatusDidChange(_ notification: Notification) {
		guard NetworkMonitor.shared.isConnected else {
			return
		}
		Task { @MainActor in
			let homePageURLs = homePagesWithTransientSearchFailure
			homePagesWithTransientSearchFailure.removeAll()
			for homePageURL in homePageURLs {
				searchForFavicon(homePageURL: homePageURL)
			}
		}
	}

	/// A favicon already in memory posts nothing when it’s looked up again, so it’s posted here.
	@objc func handleFeedSettingDidChange(_ notification: Notification) {
		guard let feed = notification.object as? Feed, let key = notification.userInfo?[Feed.SettingUserInfoKey] as? Feed.SettingKey else {
			return
		}
		guard key == .faviconURL || key == .homePageURL, feeds.contains(feed) else {
			return
		}
		postFaviconDidChange(Set([feed]))
	}

	/// New metadata may name a different favicon.
	@objc func handleHTMLMetadataAvailable(_ notification: Notification) {
		guard let homePageURL = notification.userInfo?[HTMLMetadataUserInfoKey.url] as? String else {
			assertionFailure("Expected URL string in .htmlMetadataAvailable Notification userInfo.")
			return
		}
		guard homePagesLookedUp.contains(homePageURL) else {
			return
		}

		Task { @MainActor in
			homePagesCheckedForNewFavicon.remove(homePageURL)
			if homePagesAwaitingMetadataForSearch.remove(homePageURL) != nil {
				searchForFavicon(homePageURL: homePageURL)
			} else {
				_ = favicon(forHomePageURL: homePageURL)
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

	func favicon(forHomePageURL homePageURL: String) -> IconLookup {
		homePagesLookedUp.insert(homePageURL)

		if ImageDatabase.shared.homePageHasNoFavicon(homePageURL) {
			return .unavailable
		}

		// A saved favicon that keeps failing is searched for again, in case the site moved it.
		if let faviconURL = ImageDatabase.shared.faviconURL(forHomePageURL: homePageURL), !ImageDatabase.shared.recentlyFailed(url: faviconURL) {
			checkForNewFaviconURL(homePageURL: homePageURL, savedFaviconURL: faviconURL)
			return iconImage(for: faviconURL, homePageURL: homePageURL)
		}

		searchForFavicon(homePageURL: homePageURL)
		return searches[homePageURL] == nil ? .unavailable : .loading
	}

	func iconImage(for faviconURL: String, homePageURL: String?) -> IconLookup {
		faviconURLs.insert(faviconURL)
		return IconImageDownloader.shared.iconImage(for: faviconURL, activityOwner: .faviconDownloader, activityKind: .downloadFavicon(faviconURL: faviconURL), activityDetail: homePageURL)
	}

	/// The favicon URL the feed specifies, unless it recently failed or isn’t an image,
	/// in which case the home page’s favicon is used instead.
	/// Called per row, so it doesn’t log the way `canAttemptDownload` does.
	func usableDeclaredFaviconURL(for feed: Feed) -> String? {
		guard let faviconURL = feed.faviconURL, faviconURL.hasPrefix("http://") || faviconURL.hasPrefix("https://"), !ImageDatabase.shared.recentlyFailed(url: faviconURL), !faviconURLsThatAreNotImages.contains(faviconURL) else {
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

	func homePageURLsSearching(with faviconURL: String) -> [String] {
		searches.filter { $0.value.faviconURL == faviconURL }.map { $0.key }
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

			switch iconImage(for: faviconURL, homePageURL: homePageURL) {
			case .found:
				// Already in memory, such as for another home page on the same site, so no `.iconImageDidBecomeAvailable` is coming.
				saveFoundFavicon(faviconURL, homePageURL: homePageURL)
				postFaviconDidChange(faviconURL)
				return
			case .loading:
				searches[homePageURL]?.faviconURL = faviconURL
				return
			case .unavailable:
				// Failed earlier in this session, and isn’t due to be tried again yet.
				if DownloadedImageCache.shared.isWaitingToRetry(faviconURL) {
					searches[homePageURL]?.hadTransientFailure = true
				}
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
	}

	/// The known favicon URL for `feed` (from feed settings or the home-page→favicon map), without
	/// triggering any download. Both lookups are in-memory, so this is cheap to call per feed.
	/// The home page is the same one `favicon(for:)` saves under.
	func cachedFaviconURL(for feed: Feed) -> String? {
		if let faviconURL = usableDeclaredFaviconURL(for: feed) {
			return faviconURL
		}
		if let homePageURL = faviconHomePageURL(for: feed), let faviconURL = ImageDatabase.shared.faviconURL(forHomePageURL: homePageURL) {
			return faviconURL
		}
		return nil
	}

	func postFaviconDidChange(_ faviconURL: String) {
		let feedsUsingFavicon = feeds.filter { cachedFaviconURL(for: $0) == faviconURL }
		guard !feedsUsingFavicon.isEmpty else {
			return
		}
		postFaviconDidChange(feedsUsingFavicon)
	}

	/// Posted later, since a lookup can find a favicon already in memory.
	func postFaviconDidChange(_ feeds: Set<Feed>) {
		DispatchQueue.main.async {
			NotificationCenter.default.post(name: .faviconDidChange, object: self, userInfo: [Self.feedsKey: feeds])
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
