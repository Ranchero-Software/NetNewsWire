//
//  HomePageIconDownloader.swift
//  Images
//
//  Created by Brent Simmons on 11/3/26.
//

import Foundation
import Account
import RSCore
import RSWeb
import HTMLMetadata
import ActivityLog

extension Notification.Name {
	/// Posted when a home page’s icon loads or fails, or its icon URL changes.
	/// userInfo key: `HomePageIconDownloader.feedsKey` (`Set<Feed>`, the feeds that looked up that home page).
	public static let homePageIconDidChange = Notification.Name("HomePageIconDidChange")
}

/// Gets the icon a feed’s home page specifies in its metadata: an apple-touch-icon, og:image, or twitter:image.
///
/// The icon URL is saved, so it works at launch, before the home page’s metadata is in memory.
/// A site may add, change, or move its icon, so once per session, and whenever the home page’s metadata
/// arrives, a different icon URL in the metadata replaces the saved one once its image loads.
@MainActor public final class HomePageIconDownloader {

	public static let shared = HomePageIconDownloader()
	public static let feedsKey = "feeds"

	private var feedsByHomePageURL = [String: Set<Feed>]() // home page URL: feeds that looked it up
	private var homePagesCheckedForNewIconURL = Set<String>()
	private var newIconURLs = [String: String]() // home page URL: icon URL that replaces the saved one once its image loads

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleIconImageDidBecomeAvailable(_:)), name: .iconImageDidBecomeAvailable, object: IconImageDownloader.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(handleIconImageDownloadDidFail(_:)), name: .iconImageDownloadDidFail, object: IconImageDownloader.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(handleHTMLMetadataAvailable(_:)), name: .htmlMetadataAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleFeedSettingDidChange(_:)), name: .feedSettingDidChange, object: nil)
	}

	/// Unavailable while the home page’s metadata isn’t in memory. `.homePageIconDidChange` follows when it arrives.
	public func homePageIcon(for feed: Feed) -> IconLookup {
		guard let homePageURL = Self.homePageURL(for: feed) else {
			return .unavailable
		}
		feedsByHomePageURL[homePageURL, default: Set<Feed>()].insert(feed)

		if let savedIconURL = ImageDatabase.shared.homePageIconURL(forHomePageURL: homePageURL) {
			if homePagesCheckedForNewIconURL.insert(homePageURL).inserted {
				checkForNewIconURL(homePageURL: homePageURL, savedIconURL: savedIconURL)
			}
			return iconImage(for: savedIconURL, homePageURL: homePageURL)
		}

		if ImageDatabase.shared.homePageHasNoIcon(homePageURL) {
			return .unavailable
		}
		guard let iconURL = iconURLFromMetadata(homePageURL: homePageURL) else {
			return .unavailable
		}
		return iconImage(for: iconURL, homePageURL: homePageURL)
	}

	// MARK: - Notifications

	@objc func handleIconImageDidBecomeAvailable(_ notification: Notification) {
		guard let iconURL = notification.userInfo?[IconImageDownloader.urlKey] as? String else {
			return
		}
		for (homePageURL, newIconURL) in newIconURLs where newIconURL == iconURL {
			newIconURLs[homePageURL] = nil
			ImageDatabase.shared.saveHomePageIcon(homePageURL: homePageURL, iconURL: newIconURL)
		}
		postHomePageIconDidChange(iconURL: iconURL)
	}

	/// Feeds showing this icon look again, which falls back to the next source.
	@objc func handleIconImageDownloadDidFail(_ notification: Notification) {
		guard let iconURL = notification.userInfo?[IconImageDownloader.urlKey] as? String else {
			return
		}
		newIconURLs = newIconURLs.filter { $0.value != iconURL }
		postHomePageIconDidChange(iconURL: iconURL)
	}

	@objc func handleHTMLMetadataAvailable(_ notification: Notification) {
		guard let homePageURL = notification.userInfo?[HTMLMetadataUserInfoKey.url] as? String, feedsByHomePageURL[homePageURL] != nil else {
			return
		}
		homePagesCheckedForNewIconURL.insert(homePageURL)
		if let savedIconURL = ImageDatabase.shared.homePageIconURL(forHomePageURL: homePageURL) {
			checkForNewIconURL(homePageURL: homePageURL, savedIconURL: savedIconURL)
		} else if iconURLFromMetadata(homePageURL: homePageURL) != nil {
			postHomePageIconDidChange(homePageURL: homePageURL)
		}
	}

	@objc func handleFeedSettingDidChange(_ notification: Notification) {
		guard let feed = notification.object as? Feed, let key = notification.userInfo?[Feed.SettingUserInfoKey] as? Feed.SettingKey, key == .homePageURL else {
			return
		}
		NotificationCenter.default.post(name: .homePageIconDidChange, object: self, userInfo: [Self.feedsKey: Set([feed])])
	}
}

private extension HomePageIconDownloader {

	static func homePageURL(for feed: Feed) -> String? {
		guard let homePageURL = feed.homePageURL else {
			return nil
		}
		if SpecialCase.urlStringContainSpecialCase(feed.url, SpecialCase.hostNamesWithoutFeedOrHomePageIcons) || SpecialCase.urlStringContainSpecialCase(homePageURL, SpecialCase.hostNamesWithoutFeedOrHomePageIcons) {
			return nil
		}
		return homePageURL.normalizedURL
	}

	/// Saves the icon URL, or that there is none. Nil when the metadata isn’t in memory,
	/// in which case this starts loading it, and `.htmlMetadataAvailable` follows.
	func iconURLFromMetadata(homePageURL: String) -> String? {
		guard let metadata = HTMLMetadataDownloader.shared.cachedMetadata(for: homePageURL) else {
			return nil
		}
		let iconURL = metadata.bestHomePageIconURL()
		ImageDatabase.shared.saveHomePageIcon(homePageURL: homePageURL, iconURL: iconURL)
		return iconURL
	}

	/// The saved icon keeps working if the new one fails, or if the metadata no longer specifies an icon.
	func checkForNewIconURL(homePageURL: String, savedIconURL: String) {
		guard let metadata = HTMLMetadataDownloader.shared.cachedMetadata(for: homePageURL), let iconURL = metadata.bestHomePageIconURL(), iconURL != savedIconURL else {
			return
		}
		switch iconImage(for: iconURL, homePageURL: homePageURL) {
		case .found:
			ImageDatabase.shared.saveHomePageIcon(homePageURL: homePageURL, iconURL: iconURL)
			// Called during a lookup, so the change is posted afterward.
			Task { @MainActor in
				postHomePageIconDidChange(homePageURL: homePageURL)
			}
		case .loading:
			// When it loads, `handleIconImageDidBecomeAvailable` saves it.
			newIconURLs[homePageURL] = iconURL
		case .unavailable:
			break
		}
	}

	func iconImage(for iconURL: String, homePageURL: String) -> IconLookup {
		IconImageDownloader.shared.iconImage(for: iconURL, activityOwner: .feedImageDownloader, activityKind: .downloadFeedImage(feedURL: iconURL), activityDetail: homePageURL)
	}

	func postHomePageIconDidChange(iconURL: String) {
		for homePageURL in feedsByHomePageURL.keys where ImageDatabase.shared.homePageIconURL(forHomePageURL: homePageURL) == iconURL {
			postHomePageIconDidChange(homePageURL: homePageURL)
		}
	}

	func postHomePageIconDidChange(homePageURL: String) {
		guard let feeds = feedsByHomePageURL[homePageURL] else {
			return
		}
		NotificationCenter.default.post(name: .homePageIconDidChange, object: self, userInfo: [Self.feedsKey: feeds])
	}
}
