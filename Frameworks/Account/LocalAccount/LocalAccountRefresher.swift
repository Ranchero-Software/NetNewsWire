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
	
	private lazy var downloadSession: DownloadSession = {
		return DownloadSession(delegate: self)
	}()

	var progress = DownloadProgress(numberOfTasks: 0)

	public func refreshFeeds(_ feeds: Set<Feed>) {
		progress.addToNumberOfTasksAndRemaining(feeds.count)
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
		
		var request = URLRequest(url: url)
		if let conditionalGetInfo = feed.conditionalGetInfo {
			conditionalGetInfo.addRequestHeadersToURLRequest(&request)
		}

		return request as URLRequest
	}
	
	func downloadSession(_ downloadSession: DownloadSession, downloadDidCompleteForRepresentedObject representedObject: AnyObject, response: URLResponse?, data: Data, error: NSError?, completion: @escaping () -> Void) {
		guard let feed = representedObject as? Feed, !data.isEmpty else {
			progress.completeTask()
			completion()
			return
		}

		if let error = error {
			print("Error downloading \(feed.url) - \(error)")
			progress.completeTask()
			completion()
			return
		}

		let dataHash = data.md5String
		if dataHash == feed.contentHash {
			progress.completeTask()
			completion()
			return
		}

		let parserData = ParserData(url: feed.url, data: data)
		FeedParser.parse(parserData) { (parsedFeed, error) in
			guard let account = feed.account, let parsedFeed = parsedFeed, error == nil else {
				self.progress.completeTask()
				completion()
				return
			}
			account.update(feed, with: parsedFeed) {
				if let httpResponse = response as? HTTPURLResponse {
					feed.conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
				}
				
				feed.contentHash = dataHash
				self.progress.completeTask()
				completion()
			}
		}
	}
	
	func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData data: Data, representedObject: AnyObject) -> Bool {
		guard let feed = representedObject as? Feed else {
			progress.completeTask()
			return false
		}
		
		if data.isEmpty {
			return true
		}
		if data.isDefinitelyNotFeed() {
			progress.completeTask()
			return false
		}
		
		if data.count > 4096 {
			let parserData = ParserData(url: feed.url, data: data)
			return FeedParser.mightBeAbleToParseBasedOnPartialData(parserData)
		}
		
		return true		
	}

	func downloadSession(_ downloadSession: DownloadSession, didReceiveUnexpectedResponse response: URLResponse, representedObject: AnyObject) {
		progress.completeTask()
	}

	func downloadSession(_ downloadSession: DownloadSession, didReceiveNotModifiedResponse: URLResponse, representedObject: AnyObject) {
		progress.completeTask()
	}
	
	func downloadSession(_ downloadSession: DownloadSession, didDiscardDuplicateRepresentedObject: AnyObject) {
		progress.completeTask()
	}
	
	func downloadSessionDidCompleteDownloadObjects(_ downloadSession: DownloadSession) {
		progress.clear()
	}
	
}

// MARK: - Utility

private extension Data {
	
	func isDefinitelyNotFeed() -> Bool {
		// We only detect a few image types for now. This should get fleshed-out at some later date.
		return self.isImage
	}
}
