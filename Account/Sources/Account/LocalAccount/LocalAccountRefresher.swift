//
//  LocalAccountRefresher.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser
import RSWeb
import Articles
import ArticlesDatabase
import os

protocol LocalAccountRefresherDelegate {
	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges)
}

final class LocalAccountRefresher {

	var delegate: LocalAccountRefresherDelegate?
	var downloadProgress: DownloadProgress {
		downloadSession.downloadProgress
	}

	private var completion: (() -> Void)? = nil
	private var isSuspended = false

	private lazy var downloadSession: DownloadSession = {
		return DownloadSession(delegate: self)
	}()

	private var urlToFeedDictionary = [String: WebFeed]()

	public func refreshFeeds(_ feeds: Set<WebFeed>, completion: (() -> Void)? = nil) {

		let filteredFeeds = feeds.filter { !Self.feedShouldBeSkipped($0) }

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

	public func suspend() {
		downloadSession.cancelAll()
		isSuspended = true
	}

	public func resume() {
		isSuspended = false
	}
}

// MARK: - DownloadSessionDelegate

extension LocalAccountRefresher: DownloadSessionDelegate {

	func downloadSession(_ downloadSession: DownloadSession, conditionalGetInfoFor url: URL) -> HTTPConditionalGetInfo? {

		guard let feed = urlToFeedDictionary[url.absoluteString] else {
			return nil
		}
		return feed.conditionalGetInfo
	}

	func downloadSession(_ downloadSession: DownloadSession, downloadDidComplete url: URL, response: URLResponse?, data: Data, error: NSError?) {

		guard !isSuspended else {
			return
		}
		guard let feed = urlToFeedDictionary[url.absoluteString] else {
			return
		}

		if error != nil {
			return
		}

		let conditionalGetInfo: HTTPConditionalGetInfo? = {
			if let httpResponse = response as? HTTPURLResponse {
				return HTTPConditionalGetInfo(urlResponse: httpResponse)
			}
			return nil
		}()

		if url.isOpenRSSOrgURL {
			// Supported only for openrss.org. Cache-Control headers are
			// otherwise not intentional for feeds, unfortunately.
			if let httpURLResponse = response as? HTTPURLResponse, let cacheControlInfo = CacheControlInfo(urlResponse: httpURLResponse) {
				feed.cacheControlInfo = cacheControlInfo
			}
		}

		let dataHash = data.md5String
		if dataHash == feed.contentHash {
			// It’s possible that the conditional get info has changed even if the
			// content hasn’t changed.
			// https://inessential.com/2024/08/03/netnewswire_and_conditional_get_issues.html
			feed.conditionalGetInfo = conditionalGetInfo
			return
		}

		let parserData = ParserData(url: feed.url, data: data)
		FeedParser.parse(parserData) { (parsedFeed, error) in
			
			guard let account = feed.account, let parsedFeed, error == nil else {
				return
			}
			
			account.update(feed, with: parsedFeed) { result in
				if case .success(let articleChanges) = result {
					feed.contentHash = dataHash
					feed.conditionalGetInfo = conditionalGetInfo
					self.delegate?.localAccountRefresher(self, articleChanges: articleChanges)
				}
			}
		}
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
	static func feedIsDisallowed(_ feed: WebFeed) -> Bool {

		guard let url = url(for: feed) else {
			return true
		}
		guard let lowercaseHost = url.host()?.lowercased() else {
			return true
		}

		for badHost in badHosts {
			if lowercaseHost == badHost {
				os_log(.debug, "Dropping request because it‘s X/Twitter, which doesn’t provide feeds: \(feed.url)")
				return true
			}
		}

		return false
	}

	static func feedShouldBeSkipped(_ feed: WebFeed) -> Bool {
		feedShouldBeSkippedForCacheControlReasons(feed) || feedIsDisallowed(feed)
	}

	static func feedShouldBeSkippedForCacheControlReasons(_ feed: WebFeed) -> Bool {
		// We support Cache-Control only for openrss.org. The rest of the feed-providing
		// universe hasn’t dealt with Cache-Control, and we routinely see days-long
		// max-ages for even fast-moving feeds.
		//
		// However, openrss.org does make sure their Cache-Control headers are
		// intentional, and we should honor those.
		guard let url = url(for: feed) else {
			return false
		}

		if url.isOpenRSSOrgURL {
			if let cacheControlInfo = feed.cacheControlInfo, !cacheControlInfo.canResume {
				os_log(.debug, "Dropping request for Cache-Control reasons: \(feed.url)")
				return true
			}
		}

		return false
	}

	static var urlCache = [String: URL]()

	static func url(for feed: WebFeed) -> URL? {

		assert(Thread.isMainThread)

		let urlString = feed.url

		if let url = urlCache[urlString] {
			return url
		}
		if let url = URL(unicodeString: urlString) {
			urlCache[urlString] = url
			return url
		}

		return nil
	}
}

// MARK: - Utility

private extension Data {
	
	func isDefinitelyNotFeed() -> Bool {
		// We only detect a few image types for now. This should get fleshed-out at some later date.
		return self.isImage
	}
}
