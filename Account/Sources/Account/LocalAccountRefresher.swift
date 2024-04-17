//
//  LocalAccountRefresher.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Parser
import Web
import Articles
import ArticlesDatabase
import FoundationExtras

protocol LocalAccountRefresherDelegate {
	@MainActor func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedFor: Feed)
	@MainActor func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges, completion: @escaping () -> Void)
}

@MainActor final class LocalAccountRefresher {
	
	private var completion: (() -> Void)? = nil
	private var isSuspended = false
	var delegate: LocalAccountRefresherDelegate?
	
	private lazy var downloadSession: DownloadSession = {
		return DownloadSession(delegate: self)
	}()

	private func refreshFeeds(_ feeds: Set<Feed>, completion: (() -> Void)? = nil) {
		guard !feeds.isEmpty else {
			completion?()
			return
		}
		self.completion = completion
		downloadSession.downloadObjects(feeds as NSSet)
	}
	
	public func refreshFeeds(_ feeds: Set<Feed>) async {

		await withCheckedContinuation { continuation in
			self.refreshFeeds(feeds) {
				continuation.resume()
			}
		}
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

	@MainActor func downloadSession(_ downloadSession: DownloadSession, requestForRepresentedObject representedObject: AnyObject) -> URLRequest? {
		guard let feed = representedObject as? Feed else {
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
	
	@MainActor func downloadSession(_ downloadSession: DownloadSession, downloadDidCompleteForRepresentedObject representedObject: AnyObject, response: URLResponse?, data: Data, error: NSError?, completion: @escaping () -> Void) {
		let feed = representedObject as! Feed
		
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
		Task { @MainActor in

			do {
				let parsedFeed = try await FeedParser.parse(parserData)

				guard let account = feed.account, let parsedFeed else {
					completion()
					self.delegate?.localAccountRefresher(self, requestCompletedFor: feed)
					return
				}


				let articleChanges = try await account.update(feed: feed, with: parsedFeed)

				if let httpResponse = response as? HTTPURLResponse {
					feed.conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
				}
				feed.contentHash = dataHash

				self.delegate?.localAccountRefresher(self, requestCompletedFor: feed)
				self.delegate?.localAccountRefresher(self, articleChanges: articleChanges) {
					completion()
				}

			} catch {
				completion()
				self.delegate?.localAccountRefresher(self, requestCompletedFor: feed)
			}
		}
	}

	
	func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData data: Data, representedObject: AnyObject) -> Bool {
		let feed = representedObject as! Feed
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
		let feed = representedObject as! Feed
		delegate?.localAccountRefresher(self, requestCompletedFor: feed)
	}

	func downloadSession(_ downloadSession: DownloadSession, didReceiveNotModifiedResponse: URLResponse, representedObject: AnyObject) {
		let feed = representedObject as! Feed
		delegate?.localAccountRefresher(self, requestCompletedFor: feed)
	}
	
	func downloadSession(_ downloadSession: DownloadSession, didDiscardDuplicateRepresentedObject representedObject: AnyObject) {
		let feed = representedObject as! Feed
		delegate?.localAccountRefresher(self, requestCompletedFor: feed)
	}

	func downloadSessionDidCompleteDownloadObjects(_ downloadSession: DownloadSession) {
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
