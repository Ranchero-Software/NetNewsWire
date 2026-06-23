//
//  DownloadResponse.swift
//  RSWeb
//
//  Created by Brent Simmons on 6/17/26.
//

import Foundation

/// The result of a successful `Downloader` download.
public struct DownloadResponse: Sendable {

	public let data: Data?
	public let response: URLResponse?

	/// True when served without a network request — from the short-term cache
	/// or by coalescing onto an in-progress download for the same URL.
	public let returnedFromCache: Bool

	public init(data: Data?, response: URLResponse?, returnedFromCache: Bool) {
		self.data = data
		self.response = response
		self.returnedFromCache = returnedFromCache
	}
}
