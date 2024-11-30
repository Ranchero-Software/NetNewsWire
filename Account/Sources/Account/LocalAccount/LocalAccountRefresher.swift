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
	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedFor: URL)
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
		guard !feeds.isEmpty else {
			completion?()
			return
		}

		urlToFeedDictionary.removeAll()
		for feed in feeds {
			urlToFeedDictionary[feed.url] = feed
		}

		let urls = feeds.compactMap { feed in
			URL(unicodeString: feed.url)
		}

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

	func downloadSession(_ downloadSession: DownloadSession, downloadDidComplete url: URL, response: URLResponse?, data: Data, error: NSError?) {

		defer {
			delegate?.localAccountRefresher(self, requestCompletedFor: url)
		}
		
		guard let feed = urlToFeedDictionary[url.absoluteString] else {
			return
		}
		guard !data.isEmpty, !isSuspended else {
			return
		}

		if let error {
			os_log(.debug, "Error downloading \(url) - \(error)")
			return
		}

		let dataHash = data.md5String
		if dataHash == feed.contentHash {
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
		completion?()
		completion = nil
	}
}

// MARK: - Utility

private extension Data {
	
	func isDefinitelyNotFeed() -> Bool {
		// We only detect a few image types for now. This should get fleshed-out at some later date.
		return self.isImage
	}
}
