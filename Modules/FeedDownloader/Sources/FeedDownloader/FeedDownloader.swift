//
//  FeedDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/22/24.
//  Copyright © 2024 Brent Simmons. All rights reserved.
//

import Foundation
import FoundationExtras
import os
import Web

public protocol FeedDownloaderDelegate: AnyObject {

	@MainActor func feedDownloader(_: FeedDownloader, requestCompletedForFeedURL: URL, response: URLResponse?, data: Data?, error: Error?)

	@MainActor func feedDownloader(_: FeedDownloader, requestCanceledForFeedURL: URL, response: URLResponse?, data: Data?, error: Error?, reason: FeedDownloader.CancellationReason)

	@MainActor func feedDownloaderSessionDidComplete(_: FeedDownloader)

	@MainActor func feedDownloader(_: FeedDownloader, conditionalGetInfoFor: URL) -> HTTPConditionalGetInfo?
}

/// Use this to download feeds directly (local and iCloud accounts).
@MainActor public final class FeedDownloader {

	public enum CancellationReason: CustomStringConvertible {
		
		case suspended
		case notFeedData
		case unexpectedResponse
		case notModified

		public var description: String {
			switch self {
			case .suspended:
				return "suspended"
			case .notFeedData:
				return "notFeedData"
			case .unexpectedResponse:
				return "unexpectedResponse"
			case .notModified:
				return "notModified"
			}
		}
	}

	public weak var delegate: FeedDownloaderDelegate?
	public var downloadProgress: DownloadProgress {
		downloadSession.downloadProgress
	}

	private let downloadSession: DownloadSession
	private var isSuspended = false

	public init() {

		self.downloadSession = DownloadSession()
		downloadSession.delegate = self
	}

	public func downloadFeeds(_ feedURLs: Set<URL>) {

		let feedIdentifiers = Set(feedURLs.map { $0.absoluteString })
		downloadSession.download(feedIdentifiers)
	}

	public func suspend() async {

		isSuspended = true
		await downloadSession.cancelAll()
	}

	public func resume() {

		isSuspended = false
	}
}

extension FeedDownloader: DownloadSessionDelegate {

	public func downloadSession(_ downloadSession: DownloadSession, requestForIdentifier identifier: String) -> URLRequest? {

		guard let url = URL(string: identifier) else {
			assertionFailure("There should be no case where identifier is not convertible to URL.")
			return nil
		}

		var request = URLRequest(url: url)
		if let conditionalGetInfo = delegate?.feedDownloader(self, conditionalGetInfoFor: url) {
			conditionalGetInfo.addRequestHeadersToURLRequest(&request)
		}

		return request
	}

	public func downloadSession(_ downloadSession: DownloadSession, downloadDidCompleteForIdentifier identifier: String, response: URLResponse?, data: Data?, error: Error?) {

		guard let url = URL(string: identifier) else {
			assertionFailure("There should be no case where identifier is not convertible to URL.")
			return
		}

		delegate?.feedDownloader(self, requestCompletedForFeedURL: url, response: response, data: data, error: error)
	}

	public func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData data: Data, identifier: String) -> Bool {

		guard let url = URL(string: identifier) else {
			assertionFailure("There should be no case where identifier is not convertible to URL.")
			return false
		}

		if isSuspended {
			delegate?.feedDownloader(self, requestCanceledForFeedURL: url, response: nil, data: nil, error: nil, reason: .suspended)
			return false
		}

		if data.isEmpty {
			return true
		}

		if data.isNotAFeed() {
			delegate?.feedDownloader(self, requestCanceledForFeedURL: url, response: nil, data: data, error: nil, reason: .notFeedData)
			return false
		}

		return true
	}

	public func downloadSession(_ downloadSession: DownloadSession, didReceiveUnexpectedResponse response: URLResponse, identifier: String) {

		guard let url = URL(string: identifier) else {
			assertionFailure("There should be no case where identifier is not convertible to URL.")
			return
		}

		delegate?.feedDownloader(self, requestCanceledForFeedURL: url, response: response, data: nil, error: nil, reason: .unexpectedResponse)
	}

	public func downloadSession(_ downloadSession: DownloadSession, didReceiveNotModifiedResponse response: URLResponse, identifier: String) {

		guard let url = URL(string: identifier) else {
			assertionFailure("There should be no case where identifier is not convertible to URL.")
			return
		}

		delegate?.feedDownloader(self, requestCanceledForFeedURL: url, response: response,  data: nil, error: nil, reason: .notModified)
	}

	public func downloadSession(_ downloadSession: DownloadSession, didDiscardDuplicateIdentifier: String) {

		// nothing to do
	}

	public func downloadSessionDidComplete(_ downloadSession: DownloadSession) {

		delegate?.feedDownloaderSessionDidComplete(self)
	}
}

extension Data {

	func isNotAFeed() -> Bool {

		isImage // TODO: expand this
	}
}
