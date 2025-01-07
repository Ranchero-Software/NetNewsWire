//
//  Downloader.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public typealias DownloadCallback = (Data?, URLResponse?, Error?) -> Swift.Void

/// Simple downloader, for a one-shot download like an image
/// or a web page. For a download-feeds session, see DownloadSession.
public final class Downloader {

	public static let shared = Downloader()
	private let urlSession: URLSession

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

	public func download(_ url: URL, _ completion: DownloadCallback? = nil) {
		download(URLRequest(url: url), completion)
	}

	public func download(_ urlRequest: URLRequest, _ completion: DownloadCallback? = nil) {

		var urlRequestToUse = urlRequest
		urlRequestToUse.addSpecialCaseUserAgentIfNeeded()

		let task = urlSession.dataTask(with: urlRequestToUse) { (data, response, error) in
			DispatchQueue.main.async() {
				completion?(data, response, error)
			}
		}
		task.resume()
	}
}
