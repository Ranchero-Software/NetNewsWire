//
//  LocalAccountRefresher.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import ErrorLog
import RSCore
import RSParser
import RSWeb
import Articles
import ArticlesDatabase
import os

@MainActor protocol LocalAccountRefresherDelegate {
	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges)
}

@MainActor final class LocalAccountRefresher: ProgressInfoReporter {
	var delegate: LocalAccountRefresherDelegate?

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}

	private var completion: (() -> Void)?
	private var isSuspended = false

	private lazy var downloadSession: DownloadSession = {
		let session = DownloadSession(delegate: self)
		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: session)
		return session
	}()

	private var urlToFeedDictionary = [String: Feed]()

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LocalAccountRefresher")

	@MainActor public func refreshFeeds(_ feeds: Set<Feed>) async {
		await withCheckedContinuation { continuation in
			Task { @MainActor in
				refreshFeeds(feeds) {
					continuation.resume()
				}
			}
		}
	}

	@MainActor private func refreshFeeds(_ feeds: Set<Feed>, completion: (() -> Void)? = nil) {
		let specialCaseCutoffDate = Date().bySubtracting(hours: 25)
		let filteredFeeds = feeds.filter { !Self.feedShouldBeSkipped($0, specialCaseCutoffDate) }

		guard !filteredFeeds.isEmpty else {
			Task { @MainActor in
				completion?()
			}
			return
		}

		urlToFeedDictionary.removeAll()
		for feed in filteredFeeds {
			urlToFeedDictionary[feed.url] = feed
		}

		let urls = filteredFeeds.compactMap { Self.url(for: $0) }

		self.completion = completion
		downloadSession.download(Set(urls))
	}

	@MainActor public func suspend() {
		downloadSession.cancelAll()
		isSuspended = true
	}

	@MainActor public func resume() {
		isSuspended = false
	}

	// MARK: - Notifications

	@objc func progressInfoDidChange(_ notification: Notification) {
		progressInfo = downloadSession.progressInfo
	}
}

// MARK: - DownloadSessionDelegate

@MainActor extension LocalAccountRefresher: DownloadSessionDelegate {

	func downloadSession(_ downloadSession: DownloadSession, conditionalGetInfoFor url: URL) -> HTTPConditionalGetInfo? {

		guard let feed = urlToFeedDictionary[url.absoluteString] else {
			assertionFailure("LocalAccountRefresher: expected feed for \(url)")
			Self.logger.debug("LocalAccountRefresher: expected feed for \(url)")
			return nil
		}
		guard let conditionalGetInfo = feed.conditionalGetInfo else {
			Self.logger.debug("LocalAccountRefresher: no conditional GET info for \(url)")
			return nil
		}

		// Conditional GET info is dropped every 8 days, because some servers just always
		// respond with a 304 when *any* conditional GET info is sent, which means
		// those feeds don’t get updated. By dropping conditional GET info periodically,
		// we make sure those feeds get updated.
		if let conditionalGetInfoDate = feed.conditionalGetInfoDate {
			let eightDaysAgo = Date().bySubtracting(days: 8)
			if conditionalGetInfoDate < eightDaysAgo {
				if !SpecialCase.urlStringContainSpecialCase( url.absoluteString, [SpecialCase.openRSSOrgHostName, SpecialCase.rachelByTheBayHostName]) {
					Self.logger.info("LocalAccountRefresher: dropping conditional GET info for \(url) — more than 8 days old")
					feed.conditionalGetInfo = nil
					return nil
				}
			}
		}

		return conditionalGetInfo
	}

	func downloadSession(_ downloadSession: DownloadSession, downloadDidComplete url: URL, response: URLResponse?, data: Data, error: NSError?) {

		guard let feed = urlToFeedDictionary[url.absoluteString] else {
			return
		}
		feed.lastCheckDate = Date()

		guard error == nil else {
			return
		}
		guard let httpResponse = response as? HTTPURLResponse else {
			return
		}

		let statusIsOK = httpResponse.statusIsOK
		let statusIsOKOrNotModified = statusIsOK || httpResponse.statusCode == HTTPResponseCode.notModified
		guard statusIsOKOrNotModified else {
			return
		}

		let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
		if conditionalGetInfo != feed.conditionalGetInfo {
			Self.logger.debug("LocalAccountRefresher: setting conditionalGetInfo for \(url.absoluteString)")
			feed.conditionalGetInfo = conditionalGetInfo
		}

		guard statusIsOK else {
			return
		}

		if let cacheControlInfo = CacheControlInfo(urlResponse: httpResponse) {
			Self.logger.debug("LocalAccountRefresher: setting cacheControlInfo maxAge: \(cacheControlInfo.maxAge) url: \(url.absoluteString)")
			feed.cacheControlInfo = cacheControlInfo
		}

		let dataHash = data.md5String
		if dataHash == feed.contentHash {
			return
		}

		Task { @MainActor in
			Self.logger.debug("LocalAccountRefresher: parsing feed for \(url.absoluteString)")

			let parserData = ParserData(url: feed.url, data: data)
			let parsedFeed: ParsedFeed
			do {
				guard let result = try await FeedParser.parse(parserData) else {
					return
				}
				parsedFeed = result
			} catch {
				Self.logger.error("LocalAccountRefresher: feed parse error for \(url.absoluteString): \(error.localizedDescription)")
				if let account = feed.account {
					let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: "Parsing feed", errorMessage: "\(error.localizedDescription): \(url.absoluteString)")
					NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
				}
				return
			}
			guard let account = feed.account else {
				return
			}

			assert(Thread.isMainThread)
			guard let articleChanges = try? await account.updateAsync(feed: feed, parsedFeed: parsedFeed) else {
				return
			}

			Self.logger.debug("LocalAccountRefresher: setting contentHash for \(url.absoluteString)")
			feed.contentHash = dataHash

			self.delegate?.localAccountRefresher(self, articleChanges: articleChanges)
		}
	}

	func downloadSession(_ downloadSession: DownloadSession, httpError statusCode: Int, url: URL) {
		guard let feed = urlToFeedDictionary[url.absoluteString],
			  let account = feed.account else {
			return
		}

		let transportError = TransportError.httpError(status: statusCode)
		let statusDescription = transportError.localizedDescription
		let errorMessage = "HTTP \(statusCode) \(statusDescription): \(url.absoluteString)"
		let error = NSError(domain: "NetNewsWire", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])

		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: "Downloading feed", errorMessage: error.localizedDescription)
		NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}

	func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData data: Data, url: URL) -> Bool {

		guard !data.isDefinitelyNotFeed(), !isSuspended else {
			return false
		}
		return true
	}

	func downloadSessionDidComplete(_ downloadSession: DownloadSession) {

		Task { @MainActor in
			completion?()
			completion = nil
		}
	}
}

// MARK: - Private

private extension LocalAccountRefresher {

	/// These hosts will never return a feed.
	///
	/// People may still have feeds pointing to Twitter due to our prior
	/// use of the Twitter API. (Which Twitter took away.)
	static let badHosts = ["twitter.com", "www.twitter.com", "x.com", "www.x.com"]

	/// Return true if we won’t download that feed.
	static func feedIsDisallowed(_ feed: Feed) -> Bool {

		guard let url = url(for: feed) else {
			return true
		}
		guard let lowercaseHost = url.host()?.lowercased() else {
			return true
		}

		for badHost in badHosts {
			if lowercaseHost == badHost {
				Self.logger.info("LocalAccountRefresher: Dropping request becasue it’s X/Twitter, which doesn’t provide feeds: \(feed.url)")
				return true
			}
		}

		return false
	}

	static func feedShouldBeSkipped(_ feed: Feed, _ specialCaseCutoffDate: Date) -> Bool {
		feedShouldBeSkippedForCacheControlReasons(feed) ||
		feedIsDisallowed(feed) ||
		feedShouldBeSkippedForTimingReasons(feed, specialCaseCutoffDate)
	}

	static func feedShouldBeSkippedForTimingReasons(_ feed: Feed, _ specialCaseCutoffDate: Date) -> Bool {
		guard let lastCheckDate = feed.lastCheckDate else {
			return false
		}

		if SpecialCase.urlStringContainSpecialCase(feed.url, [SpecialCase.rachelByTheBayHostName, SpecialCase.openRSSOrgHostName]) {
			if lastCheckDate > specialCaseCutoffDate {
				Self.logger.info("LocalAccountRefresher: Dropping request for special case timing reasons: \(feed.url)")
				return true
			}
		}

		return false
	}

	static let cacheControlMinMaxAge: TimeInterval = 30 * 60 // 30 minutes
	static let cacheControlMaxMaxAge: TimeInterval = 5 * 60 * 60 // 5 hours

	static func feedShouldBeSkippedForCacheControlReasons(_ feed: Feed) -> Bool {
		guard let cacheControlInfo = feed.cacheControlInfo, !cacheControlInfo.canResume else {
			return false
		}

		// openrss.org gets unclamped Cache-Control — they configure it correctly.
		if SpecialCase.urlStringContainSpecialCase(feed.url, [SpecialCase.openRSSOrgHostName]) {
			Self.logger.info("LocalAccountRefresher: Dropping request for Cache-Control reasons (openrss.org): \(feed.url)")
			return true
		}

		// All other feeds: honor Cache-Control with clamped max-age
		// (min 30 minutes, max 5 hours) because many sites misconfigure it.
		// We’ve seen max-age as long as one year (for a feed that updates frequently).
		if !cacheControlInfo.canResume(minMaxAge: cacheControlMinMaxAge, maxMaxAge: cacheControlMaxMaxAge) {
			Self.logger.info("LocalAccountRefresher: Dropping request for Cache-Control reasons: \(feed.url)")
			return true
		}

		return false
	}

	static func url(for feed: Feed) -> URL? {
		URL(string: feed.url)
	}
}

// MARK: - Utility

private extension Data {

	func isDefinitelyNotFeed() -> Bool {
		// We only detect a few image types for now. This should get fleshed-out at some later date.
		return self.isImage
	}
}
