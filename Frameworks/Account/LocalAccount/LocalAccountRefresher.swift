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

final class LocalAccountRefresher {
	
	private var completion: (() -> Void)?
	private var isSuspended = false
	
	private lazy var downloadSession: DownloadSession = {
		return DownloadSession(delegate: self)
	}()

	var progress: DownloadProgress {
		return downloadSession.progress
	}

	public func refreshFeeds(_ feeds: Set<WebFeed>, completion: @escaping () -> Void) {
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
		
		let request = NSMutableURLRequest(url: url)
		if let conditionalGetInfo = feed.conditionalGetInfo {
			conditionalGetInfo.addRequestHeadersToURLRequest(request)
		}

		return request as URLRequest
	}
	
	func downloadSession(_ downloadSession: DownloadSession, downloadDidCompleteForRepresentedObject representedObject: AnyObject, response: URLResponse?, data: Data, error: NSError?, completion: @escaping () -> Void) {
		guard let feed = representedObject as? WebFeed, !data.isEmpty, !isSuspended else {
			completion()
			return
		}

		if let error = error {
			print("Error downloading \(feed.url) - \(error)")
			completion()
			return
		}

		let dataHash = data.md5String
		if dataHash == feed.contentHash {
			completion()
			return
		}

		let parserData = ParserData(url: feed.url, data: data)
		FeedParser.parse(parserData) { (parsedFeed, error) in
			guard let account = feed.account, let parsedFeed = parsedFeed, error == nil else {
				return
			}
			account.update(feed, with: parsedFeed) { error in
				if error == nil {
					if let httpResponse = response as? HTTPURLResponse {
						feed.conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
					}

					feed.contentHash = dataHash
				}
				completion()
			}
		}
	}
	
	func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData data: Data, representedObject: AnyObject) -> Bool {
		guard !isSuspended, let feed = representedObject as? WebFeed else {
			return false
		}
		
		if data.isEmpty {
			return true
		}
		
		if data.isDefinitelyNotFeed() {
			return false
		}
		
		if data.count > 4096 {
			let parserData = ParserData(url: feed.url, data: data)
			return FeedParser.mightBeAbleToParseBasedOnPartialData(parserData)
		}
		
		return true		
	}

	func downloadSession(_ downloadSession: DownloadSession, didReceiveUnexpectedResponse response: URLResponse, representedObject: AnyObject) {
	}

	func downloadSession(_ downloadSession: DownloadSession, didReceiveNotModifiedResponse: URLResponse, representedObject: AnyObject) {
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
