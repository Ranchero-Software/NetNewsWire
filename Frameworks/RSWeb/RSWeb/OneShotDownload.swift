//
//  OneShotDownload.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public typealias OneShotDownloadCallback = (Data?, URLResponse?, Error?) -> Swift.Void

private final class OneShotDownloadManager {

	private let urlSession: URLSession
	fileprivate static let shared = OneShotDownloadManager()

	public init() {

		let sessionConfiguration = URLSessionConfiguration.ephemeral
		sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
		sessionConfiguration.httpShouldSetCookies = false
		sessionConfiguration.httpCookieAcceptPolicy = .never
		sessionConfiguration.httpMaximumConnectionsPerHost = 2
		sessionConfiguration.httpCookieStorage = nil
		sessionConfiguration.urlCache = nil
		sessionConfiguration.timeoutIntervalForRequest = 30
		
		if let userAgentHeaders = UserAgent.headers() {
			sessionConfiguration.httpAdditionalHeaders = userAgentHeaders
		}

		urlSession = URLSession(configuration: sessionConfiguration)
	}

	deinit {
		urlSession.invalidateAndCancel()
	}

	public func download(_ url: URL, _ callback: @escaping OneShotDownloadCallback) {

		let task = urlSession.dataTask(with: url) { (data, response, error) in

			DispatchQueue.main.async() {
				callback(data, response, error)
			}
		}
		task.resume()
	}
}

// Call this. It’s easier than referring to OneShotDownloadManager.
// callback is called on the main queue.

public func download(_ url: URL, _ callback: @escaping OneShotDownloadCallback) {

	OneShotDownloadManager.shared.download(url, callback)
}

// MARK: - Downloading using a cache

private struct WebCacheRecord {

    let url: URL
    let dateDownloaded: Date
    let data: Data
    let response: URLResponse
    
    func isExpired(_ timeToLive: TimeInterval) -> Bool {
        
        return Date().timeIntervalSince(dateDownloaded) > timeToLive
    }
}

private final class WebCache {
    
    private var cache = [URL: WebCacheRecord]()
    
    func cleanup(_ cleanupInterval: TimeInterval) {
        
        cache.keys.forEach { (key) in
            let cacheRecord = self[key]!
            if shouldDelete(cacheRecord, cleanupInterval) {
                cache[key] = nil
            }
        }
     }
    
    private func shouldDelete(_ cacheRecord: WebCacheRecord, _ cleanupInterval: TimeInterval) -> Bool {
        
        return Date().timeIntervalSince(cacheRecord.dateDownloaded) > cleanupInterval
    }
    
    subscript(_ url: URL) -> WebCacheRecord? {
        get {
            return cache[url]
        }
        set {
            if let cacheRecord = newValue {
                cache[url] = cacheRecord
            }
            else {
                cache[url] = nil
            }
        }
    }
}

// URLSessionConfiguration has a cache policy.
// But we don’t know how it works, and the unimplemented parts spook us a bit.
// So we use a cache that works exactly as we want it to work.

private final class DownloadWithCacheManager {

	static let shared = DownloadWithCacheManager()
	private var cache = WebCache()
	private static let timeToLive: TimeInterval = 5 * 60 // five minutes
	private static let cleanupInterval: TimeInterval = 20 * 60 // 20 minutes

	func download(_ url: URL, _ callback: @escaping OneShotDownloadCallback) {

		cache.cleanup(DownloadWithCacheManager.cleanupInterval)

		let cacheRecord: WebCacheRecord? = cache[url]
		if let cacheRecord = cacheRecord, !cacheRecord.isExpired(DownloadWithCacheManager.timeToLive) {
			callback(cacheRecord.data, cacheRecord.response, nil)
			return
		}

		download(url) { (data, response, error) in

			if let _ = error, let cacheRecord = cacheRecord {
				// In the case where a cache record has expired, but the download returned an error, we use the cache record anyway. By design.
				callback(cacheRecord.data, cacheRecord.response, nil)
				return
			}

			if let data = data, let response = response, response.statusIsOK, error == nil {
				let cacheRecord = WebCacheRecord(url: url, dateDownloaded: Date(), data: data, response: response)
				self.cache[url] = cacheRecord
			}

			callback(data, response, error)
		}
	}
}


public func downloadUsingCache(_ url: URL, _ callback: @escaping OneShotDownloadCallback) {

	DownloadWithCacheManager.shared.download(url, callback)
}
