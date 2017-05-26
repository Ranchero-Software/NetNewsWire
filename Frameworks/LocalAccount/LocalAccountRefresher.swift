//
//  LocalAccountRefresher.swift
//  LocalAccount
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSXML
import RSWeb

final class LocalAccountRefresher: DownloadSessionDelegate {
	
	weak var account: LocalAccount?
	
	private lazy var downloadSession: DownloadSession = {
		return DownloadSession(delegate: self)
	}()

	var progress: DownloadProgress {
		get {
			return downloadSession.progress
		}
	}
	
	public func refreshFeeds(_ feeds: NSSet) {
		
		downloadSession.downloadObjects(feeds)
	}

	// MARK: DownloadSessionDelegate
	
	public func downloadSession(_ downloadSession: DownloadSession, requestForRepresentedObject representedObject: AnyObject) -> URLRequest? {
		
		guard let feed = representedObject as? LocalFeed else {
			return nil
		}
		
		guard let url = URL(string: feed.url) else {
			return nil
		}
		
		let request = NSMutableURLRequest(url: url)
		if let conditionalGetInfo = feed.conditionalGetInfo, !conditionalGetInfo.isEmpty {
			conditionalGetInfo.addRequestHeadersToURLRequest(request)
		}

		return request as URLRequest
	}
	
	public func downloadSession(_ downloadSession: DownloadSession, downloadDidCompleteForRepresentedObject representedObject: AnyObject, response: URLResponse?, data: Data, error: NSError?) {
		
		guard let feed = representedObject as? LocalFeed, !data.isEmpty else {
			return
		}

		if let error = error {
			print("Error downloading \(feed.url) - \(error)")
			return
		}

		let dataHash = (data as NSData).rs_md5HashString()
		if dataHash == feed.contentHash {
//			print("Hashed content of \(feed.url) has not changed.")
			return
		}
		
		let xmlData = RSXMLData(data: data, urlString: feed.url)
		RSParseFeed(xmlData) { (parsedFeed, error) in
			
			guard let account = self.account, let parsedFeed = parsedFeed, error == nil else {
				return
			}
			account.update(feed, parsedFeed: parsedFeed) {
				
				if let httpResponse = response as? HTTPURLResponse {
					let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse)
					if !conditionalGetInfo.isEmpty || feed.conditionalGetInfo != nil {
						feed.conditionalGetInfo = conditionalGetInfo
					}
				}
				
				feed.contentHash = dataHash
			}
		}
	}
	
	public func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData data: Data, representedObject: AnyObject) -> Bool {
		
		guard let feed = representedObject as? LocalFeed else {
			return false
		}
		
		if data.isEmpty {
			return true
		}
		if data.isDefinitelyNotFeed() {
			return false
		}
		
		if data.count > 4096 {
			let xmlData = RSXMLData(data: data, urlString: feed.url)
			return RSCanParseFeed(xmlData)
		}
		
		return true		
	}

	func downloadSession(_ downloadSession: DownloadSession, didReceiveUnexpectedResponse response: URLResponse, representedObject: AnyObject) {

//		guard let feed = representedObject as? LocalFeed else {
//			return
//		}
//
//		print("Unexpected response \(response) for \(feed.url).")
	}

	func downloadSession(_ downloadSession: DownloadSession, didReceiveNotModifiedResponse: URLResponse, representedObject: AnyObject) {

//		guard let feed = representedObject as? LocalFeed else {
//			return
//		}
//
//		print("Not modified response for \(feed.url).")
	}
}

private extension Data {
	
	func isDefinitelyNotFeed() -> Bool {
		
		// We only detect a few image types for now. This should get fleshed-out at some later date.
		return (self as NSData).rs_dataIsImage()
	}
}
