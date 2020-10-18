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
		guard !feeds.isEmpty else {
			completion?()
			return
		}
		self.completion = completion
		downloadSession.downloadObjects(feeds as NSSet)
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

// MARK: - Utility

private extension Data {
	
	func isDefinitelyNotFeed() -> Bool {
		// We only detect a few image types for now. This should get fleshed-out at some later date.
		return self.isImage
	}
}
