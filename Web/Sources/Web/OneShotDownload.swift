//
//  OneShotDownload.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os

public typealias DownloadData = (data: Data?, response: URLResponse?)

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

	func download(_ url: URL) async throws -> DownloadData {

		try await withCheckedThrowingContinuation { continuation in
			download(url) { data, response, error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: (data: data, response: response))
				}
			}
		}
	}

	public func download(_ urlRequest: URLRequest) async throws -> DownloadData {

		try await withCheckedThrowingContinuation { continuation in
			download(urlRequest) { data, response, error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: (data: data, response: response))
				}
			}
		}
	}

	private func download(_ url: URL, _ completion: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) {
		let task = urlSession.dataTask(with: url, completionHandler: completion)
		task.resume()
	}

	private func download(_ urlRequest: URLRequest, _ completion: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void) {
		let task = urlSession.dataTask(with: urlRequest) { (data, response, error) in
			DispatchQueue.main.async() {
				completion(data, response, error)
			}
		}
		task.resume()
	}
}

// MARK: - Downloading using a cache

private struct WebCacheRecord {

    let url: URL
    let dateDownloaded: Date
    let data: Data
    let response: URLResponse
}

private final class WebCache: Sendable {

	private let cache = OSAllocatedUnfairLock(initialState: [URL: WebCacheRecord]())

    func cleanup(_ cleanupInterval: TimeInterval) {

		cache.withLock { d in
			let cutoffDate = Date(timeInterval: -cleanupInterval, since: Date())
			for key in d.keys {
				let cacheRecord = d[key]!
				if shouldDelete(cacheRecord, cutoffDate) {
					d[key] = nil
				}
			}
		}
     }
    
    private func shouldDelete(_ cacheRecord: WebCacheRecord, _ cutoffDate: Date) -> Bool {
        
        cacheRecord.dateDownloaded < cutoffDate
    }
    
    subscript(_ url: URL) -> WebCacheRecord? {
        get {
			cache.withLock { d in
				return d[url]
			}
        }
        set {
			cache.withLock { d in
				if let cacheRecord = newValue {
					d[url] = cacheRecord
				}
				else {
					d[url] = nil
				}
			}
        }
    }
}

// URLSessionConfiguration has a cache policy.
// But we don’t know how it works, and the unimplemented parts spook us a bit.
// So we use a cache that works exactly as we want it to work.

public final actor DownloadWithCacheManager {

	public static let shared = DownloadWithCacheManager()
	private let cache = WebCache()
	private static let timeToLive: TimeInterval = 10 * 60 // 10 minutes
	private static let cleanupInterval: TimeInterval = 5 * 60 // clean up the cache at most every 5 minutes
	private var lastCleanupDate = Date()

	public func download(_ url: URL, forceRedownload: Bool = false) async throws -> DownloadData {

		if lastCleanupDate.timeIntervalSinceNow < -DownloadWithCacheManager.cleanupInterval {
			cleanupCache()
		}

		if !forceRedownload {
			if let cacheRecord = cache[url] {
				return (cacheRecord.data, cacheRecord.response)
			}
		}

		let downloadData = try await OneShotDownloadManager.shared.download(url)

		if let data = downloadData.data, let response = downloadData.response, response.statusIsOK {
			let cacheRecord = WebCacheRecord(url: url, dateDownloaded: Date(), data: data, response: response)
			cache[url] = cacheRecord
		}

		return downloadData
	}

	public func cleanupCache() {
		lastCleanupDate = Date()
		cache.cleanup(DownloadWithCacheManager.timeToLive)
	}
}
