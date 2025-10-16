//
//  DownloadCache.swift
//  RSWeb
//
//  Created by Brent Simmons on 10/16/25.
//

import Foundation
import RSCore

struct DownloadCacheRecord: CacheRecord {
	let dateCreated = Date()
	let data: Data?
	let response: URLResponse?
	let error: NSError?

	init(data: Data?, response: URLResponse?, error: NSError?) {
		self.data = data
		self.response = response
		self.error = error
	}
}


final class DownloadCache: Sendable {
	static let shared = DownloadCache()

	private let cache = Cache<DownloadCacheRecord>(timeToLive: 60 * 13, timeBetweenCleanups: 60 * 2)

	subscript(_ key: String) -> DownloadCacheRecord? {
		get {
			cache[key]
		}
		set {
			cache[key] = newValue
		}
	}

	func add(_ urlString: String, data: Data?, response: URLResponse?, error: Error?) {
		let cacheRecord = DownloadCacheRecord(data: data, response: response, error: error as? NSError)
		cache[urlString] = cacheRecord
	}
}
