//
//  OneShotDownload.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os
import Core

public final class DownloadRecord: CacheRecord, Sendable {

	public let originalURL: URL
	public let data: Data?
	public let response: URLResponse?
	public let dateCreated: Date
	public let error: Error?

	init(originalURL: URL, data: Data?, response: URLResponse?, error: Error?) {
		self.originalURL = originalURL
		self.data = data
		self.response = response
		self.dateCreated = Date()
		self.error = error
	}
}

typealias DownloadCallback = @Sendable (DownloadRecord) -> Void

// This writes to the cache but does not read from the cache.
public final class OneShotDownloadManager: Sendable {

	public static let shared = OneShotDownloadManager()
	private let urlSession: URLSession

	init() {

		let sessionConfiguration = URLSessionConfiguration.ephemeral
		sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
		sessionConfiguration.httpShouldSetCookies = false
		sessionConfiguration.httpCookieAcceptPolicy = .never
		sessionConfiguration.httpMaximumConnectionsPerHost = 1
		sessionConfiguration.httpCookieStorage = nil
		sessionConfiguration.urlCache = nil
		sessionConfiguration.timeoutIntervalForRequest = 30
		sessionConfiguration.httpAdditionalHeaders = UserAgent.headers

		urlSession = URLSession(configuration: sessionConfiguration)
	}

	deinit {
		urlSession.invalidateAndCancel()
	}

	func download(_ url: URL, _ callback: @escaping DownloadCallback) {

		download(url) { data, response, error in
			let downloadRecord = DownloadRecord(originalURL: url, data: data, response: response, error: error)
			downloadCache[url.absoluteString] = downloadRecord
			callback(downloadRecord)
		}
	}

	private func download(_ url: URL, _ completion: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) {
		let task = urlSession.dataTask(with: url, completionHandler: completion)
		task.resume()
	}

	public func download(_ urlRequest: URLRequest) {
		// Used by the CrashReporter. Should not be used by anything else.
		let task = urlSession.dataTask(with: urlRequest) { _, _, _ in }
		task.resume()
	}
}

// MARK: - Downloading using a cache

// URLSessionConfiguration has a cache policy.
// But we don’t know how it works, so we use a cache
// that works exactly as we want it to work.

private let downloadCache = Core.Cache<DownloadRecord>(timeToLive: 5 * 60, timeBetweenCleanups: 3 * 60)

private final class DownloadRequest: Equatable, Sendable {

	private let id = UUID()
	let url: URL
	let callback: DownloadCallback

	init(url: URL, callback: @escaping DownloadCallback) {
		self.url = url
		self.callback = callback
	}

	func download(_ callback: @escaping DownloadCallback) {

		if let downloadRecord = downloadCache[url.absoluteString] {
			Task {
				callback(downloadRecord)
			}
		}
		else {
			OneShotDownloadManager.shared.download(url, callback)
		}
	}

	static func ==(lhs: DownloadRequest, rhs: DownloadRequest) -> Bool {
		lhs.id == rhs.id
	}
}

public final actor DownloadWithCacheManager {

	public static let shared = DownloadWithCacheManager()

	private static let maxConcurrentDownloads = 4
	private var queue = [DownloadRequest]()
	private var downloadsInProgress = [DownloadRequest]() // Duplicates are expected

	public func download(_ url: URL) async throws -> DownloadRecord {

		try await withCheckedThrowingContinuation { continuation in
			download(url) { downloadRecord in

				if let error = downloadRecord.error {
					continuation.resume(throwing: error)
				}
				else {
					continuation.resume(returning: downloadRecord)
				}
			}
		}
	}

	nonisolated public func cleanupCache() {

		downloadCache.cleanup()
	}
}

private extension DownloadWithCacheManager {

	func download(_ url: URL, callback: @escaping DownloadCallback) {

		let downloadRequest = DownloadRequest(url: url, callback: callback)
		queue.append(downloadRequest)

		startNextDownloadIfNeeded()
	}

	func startNextDownloadIfNeeded() {

		guard let downloadRequest = nextDownloadRequest() else {
			return
		}

		downloadsInProgress.append(downloadRequest)
		Task {
			startNextDownloadIfNeeded()
		}

		downloadRequest.download { downloadRecord in
			Task {
				await self.completeDownloadRequest(downloadRequest)
			}
			downloadRequest.callback(downloadRecord)
		}
	}

	func nextDownloadRequest() -> DownloadRequest? {

		guard downloadsInProgress.count < Self.maxConcurrentDownloads else {
			return nil
		}

		// We want a downloadRequest that does not have the same URL as any
		// in downloadsInProgress — this way the current download for
		// that URL will finish, and the result will be cached,
		// so that the next downloadRequest for that URL will
		// get its result from the cache.
		// This is actually a super-common scenario in the app —
		// this happens, for example, when downloading web pages to get
		// their metadata in order to find favicons and feed icons.
		let inProgressURLs = downloadsInProgress.map { $0.url }
		var downloadRequest: DownloadRequest?
		for oneDownloadRequest in queue {
			if !inProgressURLs.contains(oneDownloadRequest.url) {
				downloadRequest = oneDownloadRequest
				break
			}
		}

		guard let downloadRequest else {
			return nil
		}

		if let indexOfDownloadRequest = queue.firstIndex(of: downloadRequest) {
			queue.remove(at: indexOfDownloadRequest)
		}
		else {
			assertionFailure("Found downloadRequest but it’s not in the queue.")
		}

		return downloadRequest
	}

	func completeDownloadRequest(_ downloadRequest: DownloadRequest) {

		guard let indexOfDownloadRequest = downloadsInProgress.firstIndex(of: downloadRequest) else {
			assertionFailure("Expected to remove downloadRequest that is not in downloadsInProgress.")
			return
		}
		downloadsInProgress.remove(at: indexOfDownloadRequest)

		startNextDownloadIfNeeded()
	}
}
