//
//  Downloader.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os

public typealias DownloadCallback = @MainActor (Data?, URLResponse?, Error?) -> Swift.Void

/// Simple downloader, for a one-shot download like an image
/// or a web page. For a download-feeds session, see DownloadSession.
@MainActor public final class Downloader {

	public static let shared = Downloader()
	private let urlSession: URLSession
	private var callbacks = [URL: [DownloadCallback]]()
	
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Downloader")
	private static let debugLoggingEnabled = true

	private init() {
		let sessionConfiguration = URLSessionConfiguration.ephemeral
		sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
		sessionConfiguration.httpShouldSetCookies = false
		sessionConfiguration.httpCookieAcceptPolicy = .never
		sessionConfiguration.httpMaximumConnectionsPerHost = 1
		sessionConfiguration.httpCookieStorage = nil
		
		if let userAgentHeaders = UserAgent.headers() {
			sessionConfiguration.httpAdditionalHeaders = userAgentHeaders
		}

		urlSession = URLSession(configuration: sessionConfiguration)
	}

	deinit {
		urlSession.invalidateAndCancel()
	}

	public func download(_ url: URL, _ completion: @escaping DownloadCallback) {
		download(URLRequest(url: url), completion)
	}

	public func download(_ urlRequest: URLRequest, _ completion: @escaping DownloadCallback) {
		assert(Thread.isMainThread)

		guard let url = urlRequest.url else {
			Self.logger.fault("Downloader: skipping download for URLRequest without a URL")
			return
		}

		addCallback(url: url, callback: completion)

		var urlRequestToUse = urlRequest
		urlRequestToUse.addSpecialCaseUserAgentIfNeeded()

		let task = urlSession.dataTask(with: urlRequestToUse) { (data, response, error) in
			Task { @MainActor in
				self.callAndReleaseCallbacks(url, data, response, error)
			}
		}
		task.resume()
	}
}

private extension Downloader {

	func addCallback(url: URL, callback: @escaping DownloadCallback) {
		assert(Thread.isMainThread)

		if callbacks[url] == nil {
			if Self.debugLoggingEnabled {
				Self.logger.debug("Downloader: downloading \(url)")
			}
			callbacks[url] = [callback]
		} else {
			// A download is already be in progress for this URL. Don’t start a separate download.
			// Add the callback to the callbacks array for this URL.
			if Self.debugLoggingEnabled {
				Self.logger.debug("Downloader: download in progress for \(url) — adding callback")
			}
			callbacks[url]?.append(callback)
			return
		}
	}

	func callAndReleaseCallbacks(_ url: URL, _ data: Data? = nil, _ response: URLResponse? = nil, _ error: Error? = nil) {
		assert(Thread.isMainThread)

		defer {
			callbacks[url] = nil
		}

		guard let callbacksForURL = callbacks[url] else {
			assertionFailure("Downloader: downloaded URL \(url) but no callbacks found")
			Self.logger.fault("Downloader: downloaded URL \(url) but no callbacks found")
			return
		}

		if Self.debugLoggingEnabled {
			let count = callbacksForURL.count
			if count == 1 {
				Self.logger.debug("Downloader: calling 1 callback for URL \(url)")
			} else {
				Self.logger.debug("Downloader: calling \(count) callbacks for URL \(url)")
			}
		}

		for callback in callbacksForURL {
			callback(data, response, error)
		}
	}
}
