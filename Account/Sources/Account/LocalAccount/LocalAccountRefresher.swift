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

protocol LocalAccountRefresherDelegate {
	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedFor: WebFeed)
	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges, completion: @escaping () -> Void)
}

final class LocalAccountRefresher {

	private var completion: (() -> Void)? = nil
	private var isSuspended = false
	var delegate: LocalAccountRefresherDelegate?

	private lazy var downloadSession: DownloadSession = {
		return DownloadSession(delegate: self)
	}()

	public func refreshFeeds(_ feeds: Set<WebFeed>, completion: (() -> Void)? = nil) {

		let feedsToDownload = feedsWithThrottledHostsRemovedIfNeeded(feeds)

		guard !feedsToDownload.isEmpty else {
			completion?()
			return
		}

		self.completion = completion
		downloadSession.downloadObjects(feedsToDownload as NSSet)
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

	func downloadSession(_ downloadSession: DownloadSession, requestForRepresentedObject representedObject: AnyObject) -> URLRequest? {
		guard let feed = representedObject as? WebFeed else {
			return nil
		}
		guard let url = URL(string: feed.url) else {
			return nil
		}
		
		var request = URLRequest(url: url)
		if let conditionalGetInfo = feed.conditionalGetInfo {
			conditionalGetInfo.addRequestHeadersToURLRequest(&request)
		}

		return request
	}
	
	func downloadSession(_ downloadSession: DownloadSession, downloadDidCompleteForRepresentedObject representedObject: AnyObject, response: URLResponse?, data: Data, error: NSError?, completion: @escaping () -> Void) {
		let feed = representedObject as! WebFeed
		
		guard !data.isEmpty, !isSuspended else {
			completion()
			delegate?.localAccountRefresher(self, requestCompletedFor: feed)
			return
		}

		if let error = error {
			print("Error downloading \(feed.url) - \(error)")
			completion()
			delegate?.localAccountRefresher(self, requestCompletedFor: feed)
			return
		}

		let dataHash = data.md5String
		if dataHash == feed.contentHash {
			completion()
			delegate?.localAccountRefresher(self, requestCompletedFor: feed)
			return
		}

		let parserData = ParserData(url: feed.url, data: data)
		FeedParser.parse(parserData) { (parsedFeed, error) in
			
			guard let account = feed.account, let parsedFeed = parsedFeed, error == nil else {
				completion()
				self.delegate?.localAccountRefresher(self, requestCompletedFor: feed)
				return
			}
			
			account.update(feed, with: parsedFeed) { result in
				if case .success(let articleChanges) = result {
					if let httpResponse = response as? HTTPURLResponse {
						feed.conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
					}
					feed.contentHash = dataHash
					self.delegate?.localAccountRefresher(self, requestCompletedFor: feed)
					self.delegate?.localAccountRefresher(self, articleChanges: articleChanges) {
						completion()
					}
				} else {
					completion()
					self.delegate?.localAccountRefresher(self, requestCompletedFor: feed)
				}
			}
			
		}
	}
	
	func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData data: Data, representedObject: AnyObject) -> Bool {
		let feed = representedObject as! WebFeed
		guard !isSuspended else {
			delegate?.localAccountRefresher(self, requestCompletedFor: feed)
			return false
		}
		
		if data.isEmpty {
			return true
		}
		
		if data.isDefinitelyNotFeed() {
			delegate?.localAccountRefresher(self, requestCompletedFor: feed)
			return false
		}
		
		return true		
	}

	func downloadSession(_ downloadSession: DownloadSession, didReceiveUnexpectedResponse response: URLResponse, representedObject: AnyObject) {
		let feed = representedObject as! WebFeed
		delegate?.localAccountRefresher(self, requestCompletedFor: feed)
	}

	func downloadSession(_ downloadSession: DownloadSession, didReceiveNotModifiedResponse: URLResponse, representedObject: AnyObject) {
		let feed = representedObject as! WebFeed
		delegate?.localAccountRefresher(self, requestCompletedFor: feed)
	}
	
	func downloadSession(_ downloadSession: DownloadSession, didDiscardDuplicateRepresentedObject representedObject: AnyObject) {
		let feed = representedObject as! WebFeed
		delegate?.localAccountRefresher(self, requestCompletedFor: feed)
	}

	func downloadSessionDidCompleteDownloadObjects(_ downloadSession: DownloadSession) {
		completion?()
		completion = nil
	}
}

// MARK: - Throttled Hosts

private extension LocalAccountRefresher {

	// We want to support openrss.org, and possibly other domains in the future,
	// by calling their servers no more often than timeIntervalBetweenThrottledHostsReads.
	// We store the last read in UserDefaults.
	static let lastReadOfThrottledHostsDefaultsKey = "lastReadOfThrottledHosts"
	static let timeIntervalBetweenThrottledHostsReads: TimeInterval = 60 * 60 // One hour

	func feedsWithThrottledHostsRemovedIfNeeded(_ feeds: Set<WebFeed>) -> Set<WebFeed> {

		let currentDate = Date()
		let lastReadOfThrottledHostsDate = UserDefaults.standard.object(forKey: Self.lastReadOfThrottledHostsDefaultsKey) as? Date ?? Date.distantPast
		let timeIntervalSinceLastReadOfThrottledHosts = currentDate.timeIntervalSince(lastReadOfThrottledHostsDate)

		let shouldReadThrottledHosts = timeIntervalSinceLastReadOfThrottledHosts > (Self.timeIntervalBetweenThrottledHostsReads)

		if shouldReadThrottledHosts {
			UserDefaults.standard.set(currentDate, forKey: Self.lastReadOfThrottledHostsDefaultsKey)
			return feeds
		}

		return feeds.filter { !feedIsFromThrottledDomain($0) }
	}

	static let throttledHosts = ["openrss.org"]

	func feedIsFromThrottledDomain(_ feed: WebFeed) -> Bool {

		guard let url = URL(unicodeString: feed.url) else {
			return false
		}

		return urlIsThrottledDomain(url)
	}

	func urlIsThrottledDomain(_ url: URL) -> Bool {

		guard let host = url.host() else {
			return false
		}
		let lowerCaseHost = host.lowercased()

		for throttledHost in Self.throttledHosts {
			if lowerCaseHost.contains(throttledHost) {
				return true
			}
		}

		return false
	}
}

// MARK: - Utility

private extension Data {
	
	func isDefinitelyNotFeed() -> Bool {
		// We only detect a few image types for now. This should get fleshed-out at some later date.
		return self.isImage
	}
}
