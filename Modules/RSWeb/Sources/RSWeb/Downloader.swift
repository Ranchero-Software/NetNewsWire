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

		if callbacks[url] == nil {
			if Self.debugLoggingEnabled {
				Self.logger.debug("Downloader: downloading \(url)")
			}
			callbacks[url] = [completion]
		} else {
			// A download is already be in progress for this URL. Don’t start a separate download.
			// Add the callback to the callbacks array for this URL.
			if Self.debugLoggingEnabled {
				Self.logger.debug("Downloader: download in progress for \(url) — adding callback")
			}
			callbacks[url]?.append(completion)
			return
		}

		var urlRequestToUse = urlRequest
		urlRequestToUse.addSpecialCaseUserAgentIfNeeded()

		let task = urlSession.dataTask(with: urlRequestToUse) { (data, response, error) in
			Task { @MainActor in
				let callbacksForURL = self.callbacks[url]
				assert(callbacksForURL != nil)

				if let callbacksForURL {
					if Self.debugLoggingEnabled {
						let count = callbacksForURL.count
						if count == 1 {
							Self.logger.debug("Downloader: calling 1 callback for URL \(url)")
						} else {
							Self.logger.debug("Downloader: calling \(callbacksForURL.count) callbacks for URL \(url)")
						}
					}

					for completion in callbacksForURL {
						completion(data, response, error)
					}
				} else {
					assertionFailure("Downloader: downloaded URL \(url) but no callbacks found")
					Self.logger.fault("Downloader: downloaded URL \(url) but no callbacks found")
				}

				self.callbacks[url] = nil
			}
		}
		task.resume()
	}
}
