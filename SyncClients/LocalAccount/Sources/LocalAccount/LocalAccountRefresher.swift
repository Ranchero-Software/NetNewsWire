//
//  LocalAccountRefresher.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb

public protocol LocalAccountRefresherDelegate {
	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestForFeedURL: String) -> URLRequest?
	func localAccountRefresher(_ refresher: LocalAccountRefresher, feedURL: String, response: URLResponse?, data: Data, error: Error?, completion: @escaping () -> Void)
	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedForFeedURL: String)
}

public final class LocalAccountRefresher {
	
	private var completion: (() -> Void)? = nil
	private var isSuspended = false
	public var delegate: LocalAccountRefresherDelegate?
	
	private lazy var downloadSession: DownloadSession = {
		return DownloadSession(delegate: self)
	}()

	public init() {}
	
	public func refreshFeedURLs(_ feedURLs: Set<String>, completion: (() -> Void)? = nil) {
		guard !feedURLs.isEmpty else {
			completion?()
			return
		}
		self.completion = completion
		downloadSession.downloadObjects(feedURLs as NSSet)
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

	public func downloadSession(_ downloadSession: DownloadSession, requestForRepresentedObject representedObject: AnyObject) -> URLRequest? {
		let feedURL = representedObject as! String
		return delegate?.localAccountRefresher(self, requestForFeedURL: feedURL)
	}
	
	public func downloadSession(_ downloadSession: DownloadSession, downloadDidCompleteForRepresentedObject representedObject: AnyObject, response: URLResponse?, data: Data, error: NSError?, completion: @escaping () -> Void) {

		guard !isSuspended else {
			completion()
			return
		}
		
		let feedURL = representedObject as! String

		delegate?.localAccountRefresher(self, feedURL: feedURL, response: response, data: data, error: error) {
			completion()
			self.delegate?.localAccountRefresher(self, requestCompletedForFeedURL: feedURL)
		}
	}
	
	public func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData data: Data, representedObject: AnyObject) -> Bool {
		let feedURL = representedObject as! String
		guard !isSuspended else {
			delegate?.localAccountRefresher(self, requestCompletedForFeedURL: feedURL)
			return false
		}
		
		if data.isEmpty {
			return true
		}
		
		if data.isDefinitelyNotFeed() {
			delegate?.localAccountRefresher(self, requestCompletedForFeedURL: feedURL)
			return false
		}
		
		return true		
	}

	public func downloadSession(_ downloadSession: DownloadSession, didReceiveUnexpectedResponse response: URLResponse, representedObject: AnyObject) {
		let feedURL = representedObject as! String
		delegate?.localAccountRefresher(self, requestCompletedForFeedURL: feedURL)
	}

	public func downloadSession(_ downloadSession: DownloadSession, didReceiveNotModifiedResponse: URLResponse, representedObject: AnyObject) {
		let feedURL = representedObject as! String
		delegate?.localAccountRefresher(self, requestCompletedForFeedURL: feedURL)
	}
	
	public func downloadSession(_ downloadSession: DownloadSession, didDiscardDuplicateRepresentedObject representedObject: AnyObject) {
		let feedURL = representedObject as! String
		delegate?.localAccountRefresher(self, requestCompletedForFeedURL: feedURL)
	}

	public func downloadSessionDidCompleteDownloadObjects(_ downloadSession: DownloadSession) {
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
