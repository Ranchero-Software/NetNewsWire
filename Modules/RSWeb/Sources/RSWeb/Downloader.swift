//
//  Downloader.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os
import RSCore

public typealias DownloadCallback = @MainActor (DownloadResponse, Error?) -> Swift.Void

/// Simple downloader, for a one-shot download like an image
/// or a web page. For a download-feeds session, see DownloadSession.
/// Caches response for a short time for GET requests. May return cached response.
@MainActor public final class Downloader {
	public static let shared = Downloader()
	private let urlSession: URLSession
	private var callbacks = [URL: [(callback: DownloadCallback, fromCache: Bool)]]()
	private let cache = DownloadCache.shared
	private let redirectBlocker = RedirectBlocker()

	/// Optional policy consulted before following an HTTP redirect: return `false` for a
	/// destination URL that should not be followed (e.g. a tracker/ad domain), and the redirect
	/// is not followed — the request completes with the redirect response instead. `nil` (the
	/// default) follows all redirects. Applies to every download this shared instance performs.
	public var redirectValidator: (@Sendable (URL) -> Bool)? {
		get { redirectBlocker.validator }
		set { redirectBlocker.validator = newValue }
	}

	nonisolated private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Downloader")

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

		urlSession = URLSession(configuration: sessionConfiguration, delegate: redirectBlocker, delegateQueue: nil)
	}

	deinit {
		urlSession.invalidateAndCancel()
	}

	public func download(_ url: URL) async throws -> DownloadResponse {
		try await withCheckedThrowingContinuation { continuation in
			download(url) { downloadResponse, error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: downloadResponse)
				}
			}
		}
	}

	public func download(_ url: URL, _ callback: @escaping DownloadCallback) {
		assert(Thread.isMainThread)
		download(URLRequest(url: url), callback)
	}

	public func download(_ urlRequest: URLRequest, _ callback: @escaping DownloadCallback) {
		assert(Thread.isMainThread)

		guard let url = urlRequest.url else {
			Self.logger.fault("Downloader: skipping download for URLRequest without a URL")
			return
		}

		guard url.isHTTPOrHTTPSURL() else {
			Self.logger.debug("Downloader: skipping download for non-http/https URL: \(url)")
			callback(DownloadResponse(data: nil, response: nil, returnedFromCache: false), nil)
			return
		}

		let isCacheableRequest = urlRequest.httpMethod == HTTPMethod.get

		// Return cached record if available.
		if isCacheableRequest {
			if let cachedRecord = cache[url.absoluteString] {
				Self.logger.debug("Downloader: returning cached record for \(url)")
				callback(DownloadResponse(data: cachedRecord.data, response: cachedRecord.response, returnedFromCache: true), nil)
				return
			}
		}

		// Add callback. If there is already a download in progress for this URL, return early.
		if callbacks[url] == nil {
			Self.logger.debug("Downloader: downloading \(url)")
			callbacks[url] = [(callback, false)]
		} else {
			// A download is already in progress for this URL. Don’t start a separate download.
			// Add the callback to the callbacks array for this URL. This caller is coalesced
			// onto the in-progress download, so it makes no network request of its own.
			Self.logger.debug("Downloader: download in progress for \(url) — adding callback")
			callbacks[url]?.append((callback, true))
			return
		}

		var urlRequestToUse = urlRequest
		urlRequestToUse.addSpecialCaseUserAgentIfNeeded()

		let task = urlSession.dataTask(with: urlRequestToUse) { (data, response, error) in

			if isCacheableRequest {
				Self.logger.debug("Downloader: caching response for \(url)")
				self.cache.add(url.absoluteString, data: data, response: response)
			}

			Task { @MainActor in
				self.callAndReleaseCallbacks(url, data, response, error)
			}
		}
		task.resume()
	}
}

/// URLSession delegate that can veto redirects via an injected policy. Thread-safe: the session
/// calls its delegate on a background queue, while the policy is set from the main actor.
private final class RedirectBlocker: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

	private let lock = NSLock()
	private var _validator: (@Sendable (URL) -> Bool)?

	var validator: (@Sendable (URL) -> Bool)? {
		get {
			lock.lock()
			defer { lock.unlock() }
			return _validator
		}
		set {
			lock.lock()
			defer { lock.unlock() }
			_validator = newValue
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
		if let url = request.url, let validator = validator, !validator(url) {
			// Don't follow the redirect: the task completes with the redirect response, so nothing
			// is fetched from (or cached for) the disallowed destination.
			completionHandler(nil)
			return
		}
		completionHandler(request)
	}
}

private extension Downloader {

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

		let count = callbacksForURL.count
		if count == 1 {
			Self.logger.debug("Downloader: calling 1 callback for URL \(url)")
		} else {
			Self.logger.debug("Downloader: calling \(count) callbacks for URL \(url)")
		}

		for entry in callbacksForURL {
			let downloadResponse = DownloadResponse(data: data, response: response, returnedFromCache: entry.fromCache)
			entry.callback(downloadResponse, error)
		}
	}
}
