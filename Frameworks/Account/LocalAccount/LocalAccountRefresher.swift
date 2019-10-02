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
	
	private lazy var downloadSession: DownloadSession = {
		return DownloadSession(delegate: self)
	}()

	var progress: DownloadProgress {
		return downloadSession.progress
	}

	public func refreshFeeds(_ feeds: Set<Feed>, completion: @escaping () -> Void) {
		self.completion = completion
		downloadSession.downloadObjects(feeds as NSSet)
	}
}

// MARK: - DownloadSessionDelegate

extension LocalAccountRefresher: DownloadSessionDelegate {

	func downloadSession(_ downloadSession: DownloadSession, requestForRepresentedObject representedObject: AnyObject) -> URLRequest? {
		guard let feed = representedObject as? Feed else {
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
	
	func downloadSession(_ downloadSession: DownloadSession, downloadDidCompleteForRepresentedObject representedObject: AnyObject, response: URLResponse?, data: Data, error: NSError?) {
		guard let feed = representedObject as? Feed, !data.isEmpty else {
			return
		}

		if let error = error {
			print("Error downloading \(feed.url) - \(error)")
			return
		}

		let dataHash = (data as NSData).rs_md5HashString()
		if dataHash == feed.contentHash {
			return
		}

		let parserData = ParserData(url: feed.url, data: data)
		FeedParser.parse(parserData) { (parsedFeed, error) in
			guard let account = feed.account, let parsedFeed = parsedFeed, error == nil else {
				return
			}
			account.update(feed, with: parsedFeed) {
				if let httpResponse = response as? HTTPURLResponse {
					feed.conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
				}
				
				feed.contentHash = dataHash
			}
		}
	}
	
	func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData data: Data, representedObject: AnyObject) -> Bool {
		guard let feed = representedObject as? Feed else {
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
		return (self as NSData).rs_dataIsImage()
	}
}
