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
import ActivityLog
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

	/// Settable by the caller (LocalAccountDelegate / CloudKitAccountDelegate) so
	/// per-refresh activities can be scoped to the right account.
	var accountID: String?

	/// When false, refreshFeeds does not create its own `.refreshAll` activity.
	var publishesRefreshActivity = true

	/// Human-readable stats summary for the most recent (or in-progress) refresh.
	var refreshStatsMessage: String {
		var parts = [String]()
		parts.append("\(feedsTotal) \(feedsTotal == 1 ? "feed" : "feeds")")
		if feedsSkipped > 0 {
			parts.append("\(feedsSkipped) skipped")
		}
		if feedsErrored > 0 {
			parts.append("\(feedsErrored) \(feedsErrored == 1 ? "error" : "errors")")
		}
		parts.append("\(newArticlesCount) new \(newArticlesCount == 1 ? "article" : "articles")")
		parts.append("\(updatedArticlesCount) updated \(updatedArticlesCount == 1 ? "article" : "articles")")
		return parts.joined(separator: ", ")
	}

	private var refreshActivityID: Int?
	private var feedsTotal = 0
	private var feedsSkipped = 0
	private var feedsErrored = 0
	private var newArticlesCount = 0
	private var updatedArticlesCount = 0
	private var outstandingParseTasks = 0
	private var downloadSessionIsComplete = false

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
		let redditURLToRefresh = Self.redditURLToRefresh(in: feeds)

		var filteredFeeds = Set<Feed>()
		var skippedFeeds = [(Feed, String)]() // feed and skip reason

		for feed in feeds {
			let (shouldSkip, reason) = Self.feedShouldBeSkipped(feed, specialCaseCutoffDate, redditURLToRefresh)
			if shouldSkip, let reason {
				skippedFeeds.append((feed, reason))
			} else {
				filteredFeeds.insert(feed)
			}
		}

		feedsTotal = feeds.count
		feedsSkipped = skippedFeeds.count
		feedsErrored = 0
		newArticlesCount = 0
		updatedArticlesCount = 0
		outstandingParseTasks = 0
		downloadSessionIsComplete = false

		// Create a pending activity for each feed that will be fetched,
		// to be completed later by the DownloadSessionDelegate callbacks.
		// Log skipped feeds as already completed with their reason.
		if let owner = activityOwner {
			let activityLog = ActivityLog.shared
			if publishesRefreshActivity {
				refreshActivityID = activityLog.createActivity(owner: owner, kind: .refreshAll)
				activityLog.didStart(id: refreshActivityID!)
			}
			for feed in filteredFeeds {
				activityLog.createActivity(owner: owner, kind: .refreshFeedContent(feedURL: feed.url), detail: feed.nameForDisplay)
			}
			for (feed, reason) in skippedFeeds {
				activityLog.logCompletedActivity(owner: owner, kind: .refreshFeedContent(feedURL: feed.url), detail: feed.nameForDisplay, message: reason)
			}
		}

		guard !filteredFeeds.isEmpty else {
			// All feeds were skipped. Still need to complete the parent activity.
			downloadSessionIsComplete = true
			completeRefreshActivityIfReady()
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

	private var activityOwner: ActivityOwner? {
		guard let accountID else {
			return nil
		}
		let displayName = AccountManager.shared.existingAccount(accountID: accountID)?.nameForDisplay ?? accountID
		return .account(accountID: accountID, displayName: displayName)
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

	func downloadSession(_ downloadSession: DownloadSession, didReceiveResponse url: URL) {
		guard let feed = urlToFeedDictionary[url.absoluteString], let owner = activityOwner else {
			return
		}
		ActivityLog.shared.didStart(owner, kind: .refreshFeedContent(feedURL: feed.url))
	}

	func downloadSession(_ downloadSession: DownloadSession, didFollowRedirectFor url: URL, from fromURL: URL, to toURL: URL, statusCode: Int) {
		guard let owner = activityOwner else {
			return
		}
		let detail = urlToFeedDictionary[url.absoluteString]?.nameForDisplay
		ActivityLog.shared.logCompletedActivity(owner: owner, kind: .followFeedRedirect, detail: detail, message: "\(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode)): \(fromURL.absoluteString) → \(toURL.absoluteString)")
	}

	func downloadSession(_ downloadSession: DownloadSession, didSkip url: URL, reason: String) {
		guard let owner = activityOwner else {
			return
		}
		let kind = ActivityKind.refreshFeedContent(feedURL: url.absoluteString)
		ActivityLog.shared.startIfNeeded(owner, kind: kind)
		ActivityLog.shared.didComplete(owner, kind: kind, message: reason, durationIsSignificant: false)
	}

	func downloadSession(_ downloadSession: DownloadSession, downloadDidComplete url: URL, response: URLResponse?, data: Data, error: NSError?) {

		guard let feed = urlToFeedDictionary[url.absoluteString] else {
			return
		}
		feed.lastCheckDate = Date()

		let activityKind = ActivityKind.refreshFeedContent(feedURL: feed.url)

		if let error {
			reportFeedRefreshError(feed: feed, error: error, activityKind: activityKind)
			return
		}
		guard let httpResponse = response as? HTTPURLResponse else {
			let error = NSError(domain: "LocalAccountRefresher", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unexpected response (not HTTP)"])
			reportFeedRefreshError(feed: feed, error: error, activityKind: activityKind)
			return
		}

		feed.lastResponseCode = httpResponse.statusCode

		let statusIsOK = httpResponse.statusIsOK
		let statusIsOKOrNotModified = statusIsOK || httpResponse.statusCode == HTTPResponseCode.notModified
		guard statusIsOKOrNotModified else {
			let statusCode = httpResponse.statusCode
			let error = NSError(domain: "LocalAccountRefresher", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode)"])
			reportFeedRefreshError(feed: feed, error: error, activityKind: activityKind)
			return
		}

		let activityOwner = self.activityOwner

		let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
		if conditionalGetInfo != feed.conditionalGetInfo {
			Self.logger.debug("LocalAccountRefresher: setting conditionalGetInfo for \(url.absoluteString)")
			feed.conditionalGetInfo = conditionalGetInfo
		}

		guard statusIsOK else {
			// 304 Not Modified
			if let activityOwner {
				ActivityLog.shared.didComplete(activityOwner, kind: activityKind, message: "304 Not Modified", durationIsSignificant: false)
			}
			return
		}

		if let cacheControlInfo = CacheControlInfo(urlResponse: httpResponse) {
			Self.logger.debug("LocalAccountRefresher: setting cacheControlInfo maxAge: \(cacheControlInfo.maxAge) url: \(url.absoluteString)")
			feed.cacheControlInfo = cacheControlInfo
		}

		let dataHash = data.md5String
		let dataSizeMessage = ActivityLog.dataSizeMessage(data)
		if dataHash == feed.contentHash {
			if let activityOwner {
				ActivityLog.shared.didComplete(activityOwner, kind: activityKind, message: "\(dataSizeMessage), content unchanged")
			}
			return
		}

		outstandingParseTasks += 1
		Task { @MainActor in
			defer {
				self.outstandingParseTasks -= 1
				self.completeRefreshActivityIfReady()
			}

			Self.logger.debug("LocalAccountRefresher: parsing feed for \(url.absoluteString)")

			let parserData = ParserData(url: feed.url, data: data)
			let parsedFeed: ParsedFeed
			do {
				guard let result = try await FeedParser.parse(parserData) else {
					if let activityOwner {
						ActivityLog.shared.didComplete(activityOwner, kind: activityKind, message: dataSizeMessage)
					}
					return
				}
				parsedFeed = result
			} catch {
				Self.logger.error("LocalAccountRefresher: feed parse error for \(url.absoluteString): \(error.localizedDescription)")
				if let activityOwner {
					ActivityLog.shared.didFail(activityOwner, kind: activityKind, error: error)
				}
				self.feedsErrored += 1
				if let account = feed.account {
					let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: "Parsing feed", errorMessage: "\(error.localizedDescription): \(url.absoluteString)")
					NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
				}
				return
			}
			guard let account = feed.account else {
				if let activityOwner {
					ActivityLog.shared.didComplete(activityOwner, kind: activityKind, message: dataSizeMessage)
				}
				return
			}

			assert(Thread.isMainThread)
			let articleChanges = await account.updateAsync(feed: feed, parsedFeed: parsedFeed)

			self.newArticlesCount += articleChanges.new?.count ?? 0
			self.updatedArticlesCount += articleChanges.updated?.count ?? 0

			Self.logger.debug("LocalAccountRefresher: setting contentHash for \(url.absoluteString)")
			feed.contentHash = dataHash

			if let activityOwner {
				ActivityLog.shared.didComplete(activityOwner, kind: activityKind, message: dataSizeMessage)
			}

			self.delegate?.localAccountRefresher(self, articleChanges: articleChanges)
		}
	}

	func downloadSession(_ downloadSession: DownloadSession, httpError statusCode: Int, url: URL) {
		guard let feed = urlToFeedDictionary[url.absoluteString] else {
			return
		}

		feed.lastCheckDate = Date()
		feed.lastResponseCode = statusCode

		let webserviceError = WebserviceError.httpError(status: statusCode)
		let statusDescription = webserviceError.localizedDescription
		let errorMessage = "HTTP \(statusCode) \(statusDescription): \(url.absoluteString)"
		let error = NSError(domain: "NetNewsWire", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])

		reportFeedRefreshError(feed: feed, error: error, activityKind: .refreshFeedContent(feedURL: feed.url))
	}

	private func reportFeedRefreshError(feed: Feed, error: Error, activityKind: ActivityKind) {
		if let activityOwner {
			ActivityLog.shared.didFail(activityOwner, kind: activityKind, error: error)
		}
		feedsErrored += 1
		guard let account = feed.account else {
			return
		}
		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: account.nameForDisplay, sourceID: account.type.rawValue, operation: "Downloading feed: \(feed.url)", errorMessage: AccountError.detailedErrorMessage(error))
		NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}

	func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData data: Data, url: URL) -> Bool {

		guard !data.isDefinitelyNotFeed(), !isSuspended else {
			return false
		}
		return true
	}

	func downloadSessionDidComplete(_ downloadSession: DownloadSession) {

		if let accountID {
			completeRemainingActivities(accountID: accountID)
		}

		downloadSessionIsComplete = true
		completeRefreshActivityIfReady()

		Task { @MainActor in
			completion?()
			completion = nil
		}
	}
}

// MARK: - Activity Helpers

@MainActor private extension LocalAccountRefresher {

	func completeRefreshActivityIfReady() {
		guard downloadSessionIsComplete && outstandingParseTasks == 0 else {
			return
		}
		guard let refreshActivityID else {
			return
		}

		ActivityLog.shared.didComplete(id: refreshActivityID, message: refreshStatsMessage)
		self.refreshActivityID = nil
	}

	/// Cleans up any leftover per-feed activities at the end of a refresh.
	/// Defense-in-depth for paths we didn’t explicitly cover (e.g. a feed
	/// the DownloadSession dropped without a `didSkip` callback).
	func completeRemainingActivities(accountID: String) {
		let displayName = AccountManager.shared.existingAccount(accountID: accountID)?.nameForDisplay ?? accountID
		let owner = ActivityOwner.account(accountID: accountID, displayName: displayName)
		let activityLog = ActivityLog.shared

		for activity in activityLog.pendingActivities(for: owner) where activity.kind != .refreshAll {
			activityLog.startIfNeeded(owner, kind: activity.kind)
			activityLog.didComplete(owner, kind: activity.kind)
		}
		for activity in activityLog.runningActivities(for: owner) where activity.kind != .refreshAll {
			activityLog.didComplete(owner, kind: activity.kind)
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

	/// Hosts that are exempt from the minimum time between refreshes
	/// even when they don’t send a Cache-Control header.
	///
	/// Feeds that send Cache-Control are already exempt (see
	/// `feedShouldBeSkippedForTimingReasons`); this list is a safety
	/// net for some domains that may or may not send Cache-Control.
	/// The 5-hour Cache-Control cap in
	/// `feedShouldBeSkippedForCacheControlReasons` still applies.
	///
	/// We have permissions from the feed owners for each of these.
	static let domainsWithNoMinimumTime: Set<String> = [
		"inessential.com", "ranchero.com", "netnewswire.blog",
		"daringfireball.net", "redsweater.com", "indiestack.com",
		"blog.plunkitup.com", "bitsplitting.org", "allenpike.com",
		"hypercritical.co", "micro.inessential.com", "discourse.netnewswire.com",
		"onefoottsunami.com", "manton.org", "randsinrepose.com",
		"micro.blog", "shapeof.com", "flyingmeat.com"
	]

	/// Returns whether this feed should be skipped and the reason if so.
	static func feedShouldBeSkipped(_ feed: Feed, _ specialCaseCutoffDate: Date, _ redditURLToRefresh: String?) -> (Bool, String?) {
		let (skipForCacheControl, cacheControlReason) = feedShouldBeSkippedForCacheControlReasons(feed)
		if skipForCacheControl {
			return (true, cacheControlReason)
		}
		let (skipForDisallowedHost, disallowedHostReason) = feedShouldBeSkippedForDisallowedHostReasons(feed)
		if skipForDisallowedHost {
			return (true, disallowedHostReason)
		}
		let (skipForReddit, redditReason) = feedShouldBeSkippedForRedditReasons(feed, redditURLToRefresh)
		if skipForReddit {
			return (true, redditReason)
		}
		let (skipForTiming, timingReason) = feedShouldBeSkippedForTimingReasons(feed, specialCaseCutoffDate)
		if skipForTiming {
			return (true, timingReason)
		}
		return (false, nil)
	}

	/// Reddit rate-limits to one feed per minute, so we
	/// refresh the least recently checked one.
	static func redditURLToRefresh(in feeds: Set<Feed>) -> String? {
		let redditFeeds = feeds.filter { SpecialCase.urlStringMatchesDomain($0.url, [SpecialCase.redditHostName]) }
		let winner = redditFeeds.min { ($0.lastCheckDate ?? .distantPast) < ($1.lastCheckDate ?? .distantPast) }
		return winner?.url
	}

	static func feedShouldBeSkippedForRedditReasons(_ feed: Feed, _ redditURLToRefresh: String?) -> (Bool, String?) {
		guard SpecialCase.urlStringMatchesDomain(feed.url, [SpecialCase.redditHostName]) else {
			return (false, nil)
		}
		if feed.url == redditURLToRefresh {
			return (false, nil)
		}
		var reason = "Skipped — Reddit allows only one feed per minute"
		if let redditURLToRefresh {
			reason += " — refreshing \(redditURLToRefresh) this time"
		}
		return (true, reason)
	}

	static func feedShouldBeSkippedForDisallowedHostReasons(_ feed: Feed) -> (Bool, String?) {
		guard let url = url(for: feed) else {
			return (true, "Skipped — invalid URL")
		}
		guard let lowercaseHost = url.host()?.lowercased() else {
			return (true, "Skipped — no host")
		}

		for badHost in badHosts {
			if lowercaseHost == badHost {
				Self.logger.info("LocalAccountRefresher: Dropping request because it’s X/Twitter, which doesn’t provide feeds: \(feed.url)")
				return (true, "Skipped — host does not provide feeds")
			}
		}

		return (false, nil)
	}

	static let minimumTimeBetweenChecks: TimeInterval = 9 * 60 // 9 minutes

	static func feedShouldBeSkippedForTimingReasons(_ feed: Feed, _ specialCaseCutoffDate: Date) -> (Bool, String?) {
		guard let lastCheckDate = feed.lastCheckDate else {
			return (false, nil)
		}

		// Feeds that send a Cache-Control header are handled elsewhere.
		if feed.cacheControlInfo != nil {
			return (false, nil)
		}

		// Hosts exempt from the minimum time between refreshes.
		if SpecialCase.urlStringMatchesDomain(feed.url, Array(domainsWithNoMinimumTime)) {
			return (false, nil)
		}

		let minutesAgo = Int(Date().timeIntervalSince(lastCheckDate) / 60)
		let minutesAgoText = "\(minutesAgo) minute\(minutesAgo == 1 ? "" : "s") ago"

		if SpecialCase.urlStringContainSpecialCase(feed.url, [SpecialCase.rachelByTheBayHostName, SpecialCase.openRSSOrgHostName]) {
			if lastCheckDate > specialCaseCutoffDate {
				let minimumHours = Int(-specialCaseCutoffDate.timeIntervalSinceNow / 3600)
				let minimumHoursText = "\(minimumHours) hour\(minimumHours == 1 ? "" : "s")"
				Self.logger.info("LocalAccountRefresher: Dropping request for special case timing reasons: \(feed.url)")
				return (true, "Skipped — previous check was \(minutesAgoText) — minimum is \(minimumHoursText)")
			}
		}

		if Date().timeIntervalSince(lastCheckDate) < minimumTimeBetweenChecks {
			let minimumMinutes = Int(minimumTimeBetweenChecks / 60)
			let minimumMinutesText = "\(minimumMinutes) minute\(minimumMinutes == 1 ? "" : "s")"
			Self.logger.info("LocalAccountRefresher: Dropping request — previous check was \(minutesAgoText): \(feed.url)")
			return (true, "Skipped — previous check was \(minutesAgoText) — minimum is \(minimumMinutesText)")
		}

		return (false, nil)
	}

	static let cacheControlMaxMaxAge: TimeInterval = 5 * 60 * 60 // 5 hours

	static let cacheControlTimeFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .short
		return formatter
	}()

	static func feedShouldBeSkippedForCacheControlReasons(_ feed: Feed) -> (Bool, String?) {
		guard let cacheControlInfo = feed.cacheControlInfo, !cacheControlInfo.canResume else {
			return (false, nil)
		}

		// openrss.org gets unclamped Cache-Control — they configure it correctly.
		if SpecialCase.urlStringContainSpecialCase(feed.url, [SpecialCase.openRSSOrgHostName]) {
			let resumeDate = cacheControlInfo.dateCreated + cacheControlInfo.maxAge
			let readyTime = cacheControlTimeFormatter.string(from: resumeDate)
			Self.logger.info("LocalAccountRefresher: Dropping request for Cache-Control reasons (openrss.org): \(feed.url)")
			return (true, "Skipped — Cache-Control, ready at \(readyTime)")
		}

		// All other feeds: honor Cache-Control with a max max-age
		// because many sites misconfigure it. We’ve seen max-age as
		// long as 16 years (for a feed that updates frequently).
		if !cacheControlInfo.canResume(maxMaxAge: cacheControlMaxMaxAge) {
			let clampedMaxAge = min(cacheControlMaxMaxAge, cacheControlInfo.maxAge)
			let resumeDate = cacheControlInfo.dateCreated + clampedMaxAge
			let readyTime = cacheControlTimeFormatter.string(from: resumeDate)
			Self.logger.info("LocalAccountRefresher: Dropping request for Cache-Control reasons: \(feed.url)")
			return (true, "Skipped — Cache-Control, ready at \(readyTime)")
		}

		return (false, nil)
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
