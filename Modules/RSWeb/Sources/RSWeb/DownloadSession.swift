//
//  DownloadSession.swift
//  RSWeb
//
//  Created by Brent Simmons on 3/12/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os

// Create a DownloadSessionDelegate, then create a DownloadSession.
// To download things: call download with a set of URLs. DownloadSession will call the various delegate methods.

public protocol DownloadSessionDelegate {

	func downloadSession(_ downloadSession: DownloadSession, conditionalGetInfoFor: URL) -> HTTPConditionalGetInfo?
	func downloadSession(_ downloadSession: DownloadSession, downloadDidComplete: URL, response: URLResponse?, data: Data, error: NSError?)
	func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData: Data, url: URL) -> Bool
	func downloadSessionDidComplete(_ downloadSession: DownloadSession)
}

@objc public final class DownloadSession: NSObject {

	public let downloadProgress = DownloadProgress(numberOfTasks: 0)

	private var urlSession: URLSession!
	private var tasksInProgress = Set<URLSessionTask>()
	private var tasksPending = Set<URLSessionTask>()
	private var taskIdentifierToInfoDictionary = [Int: DownloadInfo]()
	private var urlsInSession = Set<URL>()
	private let delegate: DownloadSessionDelegate
	private var redirectCache = [URL: URL]()
	private var queue = [URL]()

	// 429 Too Many Requests responses
	private var retryAfterMessages = [String: HTTPResponse429]()

	/// URLs with 400-499 responses (except for 429).
	/// These URLs are skipped for the rest of the session.
	private var urlsWith400s = Set<URL>()

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DownloadSession")

	public init(delegate: DownloadSessionDelegate) {

		self.delegate = delegate

		super.init()
		
		let sessionConfiguration = URLSessionConfiguration.ephemeral
		sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
		sessionConfiguration.timeoutIntervalForRequest = 15.0
		sessionConfiguration.httpShouldSetCookies = false
		sessionConfiguration.httpCookieAcceptPolicy = .never
		sessionConfiguration.httpMaximumConnectionsPerHost = 1
		sessionConfiguration.httpCookieStorage = nil
		sessionConfiguration.urlCache = nil

		if let userAgentHeaders = UserAgent.headers() {
			sessionConfiguration.httpAdditionalHeaders = userAgentHeaders
		}

		urlSession = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: OperationQueue.main)		
	}
	
	deinit {
		urlSession.invalidateAndCancel()
	}

	// MARK: - API

	public func cancelAll() {
		urlSession.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
			dataTasks.forEach { $0.cancel() }
			uploadTasks.forEach { $0.cancel() }
			downloadTasks.forEach { $0.cancel() }
		}
	}

	public func download(_ urls: Set<URL>) {

		let filteredURLs = Self.filteredURLs(urls)

		for url in filteredURLs {
			addDataTask(url)
		}

		urlsInSession = filteredURLs
		updateDownloadProgress()
	}
}

// MARK: - URLSessionTaskDelegate

extension DownloadSession: URLSessionTaskDelegate {

	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

		defer {
			removeTask(task)
		}

		guard let info = infoForTask(task) else {
			return
		}

		delegate.downloadSession(self, downloadDidComplete: info.url, response: info.urlResponse, data: info.data as Data, error: error as NSError?)
	}

	private static let redirectStatusCodes = Set([HTTPResponseCode.redirectPermanent, HTTPResponseCode.redirectTemporary, HTTPResponseCode.redirectVeryTemporary, HTTPResponseCode.redirectPermanentPreservingMethod])

	public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {

		if Self.redirectStatusCodes.contains(response.statusCode) {
			if let oldURL = task.originalRequest?.url, let newURL = request.url {
				cacheRedirect(oldURL, newURL)
			}
		}

		var modifiedRequest = request

		if let url = request.url, url.isOpenRSSOrgURL {
			modifiedRequest.setValue(UserAgent.openRSSOrgUserAgent, forHTTPHeaderField: HTTPRequestHeader.userAgent)
		}

		completionHandler(modifiedRequest)
	}
}

// MARK: - URLSessionDataDelegate

extension DownloadSession: URLSessionDataDelegate {

	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

		defer {
			updateDownloadProgress()
		}

		tasksInProgress.insert(dataTask)
		tasksPending.remove(dataTask)

		let taskInfo = infoForTask(dataTask)
		if let taskInfo {
			taskInfo.urlResponse = response
		}

		if !response.statusIsOK {

			completionHandler(.cancel)
			removeTask(dataTask)

			let statusCode = response.forcedStatusCode

			if statusCode == HTTPResponseCode.tooManyRequests {
				handle429Response(dataTask, response)
			} else if (400...499).contains(statusCode), let url = response.url {
				urlsWith400s.insert(url)
			}

			return
		}

		addDataTaskFromQueueIfNecessary()
		completionHandler(.allow)
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

		guard let info = infoForTask(dataTask) else {
			return
		}
		info.addData(data)

		if !delegate.downloadSession(self, shouldContinueAfterReceivingData: info.data as Data, url: info.url) {
			dataTask.cancel()
			removeTask(dataTask)
		}
	}
}

// MARK: - Private

private extension DownloadSession {

	func addDataTask(_ url: URL) {

		guard tasksPending.count < 500 else {
			queue.insert(url, at: 0)
			return
		}

		// If received permanent redirect earlier, use that URL.
		let urlToUse = cachedRedirect(for: url) ?? url

		if requestShouldBeDroppedDueToActive429(urlToUse) {
			Self.logger.info("Dropping request for previous 429: \(urlToUse)")
			return
		}
		if requestShouldBeDroppedDueToPrevious400(urlToUse) {
			Self.logger.info("Dropping request for previous 400-499: \(urlToUse)")
			return
		}

		let urlRequest: URLRequest = {
			var request = URLRequest(url: urlToUse)
			if let conditionalGetInfo = delegate.downloadSession(self, conditionalGetInfoFor: url) {
				conditionalGetInfo.addRequestHeadersToURLRequest(&request)
			}
			if url.isOpenRSSOrgURL {
				request.setValue(UserAgent.openRSSOrgUserAgent, forHTTPHeaderField: HTTPRequestHeader.userAgent)
			}
			return request
		}()

		let task = urlSession.dataTask(with: urlRequest)

		let info = DownloadInfo(url)
		taskIdentifierToInfoDictionary[task.taskIdentifier] = info

		tasksPending.insert(task)
		task.resume()
	}

	func addDataTaskFromQueueIfNecessary() {
		guard tasksPending.count < 500, let url = queue.popLast() else { return }
		addDataTask(url)
	}

	func infoForTask(_ task: URLSessionTask) -> DownloadInfo? {
		return taskIdentifierToInfoDictionary[task.taskIdentifier]
	}

	func removeTask(_ task: URLSessionTask) {
		tasksInProgress.remove(task)
		tasksPending.remove(task)
		taskIdentifierToInfoDictionary[task.taskIdentifier] = nil

		addDataTaskFromQueueIfNecessary()

		updateDownloadProgress()
	}

	func urlStringIsBlackListedRedirect(_ urlString: String) -> Bool {

		// Hotels and similar often do permanent redirects. We can catch some of those.

		let s = urlString.lowercased()
		let badStrings = ["solutionip", "lodgenet", "monzoon", "landingpage", "btopenzone", "register", "login", "authentic"]

		for oneBadString in badStrings {
			if s.contains(oneBadString) {
				return true
			}
		}

		return false
	}

	func cacheRedirect(_ oldURL: URL, _ newURL: URL) {
		if urlStringIsBlackListedRedirect(newURL.absoluteString) {
			return
		}
		redirectCache[oldURL] = newURL
	}

	func cachedRedirect(for url: URL) -> URL? {

		// Follow chains of redirects, but avoid loops.

		var urls = Set<URL>()
		urls.insert(url)

		var currentURL = url

		while(true) {

			if let oneRedirectURL = redirectCache[currentURL] {

				if urls.contains(oneRedirectURL) {
					// Cycle. Bail.
					return nil
				}
				urls.insert(oneRedirectURL)
				currentURL = oneRedirectURL
			}

			else {
				break
			}
		}

		if currentURL == url {
			return nil
		}
		return currentURL
	}

	// MARK: - Download Progress

	func updateDownloadProgress() {

		downloadProgress.numberOfTasks = urlsInSession.count

		let numberRemaining = tasksPending.count + tasksInProgress.count + queue.count
		downloadProgress.numberRemaining = min(numberRemaining, downloadProgress.numberOfTasks)

		// Complete?
		if downloadProgress.numberOfTasks > 0 && downloadProgress.numberRemaining < 1 {
			delegate.downloadSessionDidComplete(self)
			urlsInSession.removeAll()
		}
	}

	// MARK: - 429 Too Many Requests

	func handle429Response(_ dataTask: URLSessionDataTask, _ response: URLResponse) {

		guard let message = createHTTPResponse429(dataTask, response) else {
			return
		}

		retryAfterMessages[message.host] = message
		cancelAndRemoveTasksWithHost(message.host)
	}

	func createHTTPResponse429(_ dataTask: URLSessionDataTask, _ response: URLResponse) -> HTTPResponse429? {

		guard let url = dataTask.currentRequest?.url ?? dataTask.originalRequest?.url else {
			return nil
		}
		guard let httpResponse = response as? HTTPURLResponse else {
			return nil
		}
		guard let retryAfterValue = httpResponse.value(forHTTPHeaderField: HTTPResponseHeader.retryAfter) else {
			return nil
		}
		guard let retryAfter = TimeInterval(retryAfterValue), retryAfter > 0 else {
			return nil
		}

		return HTTPResponse429(url: url, retryAfter: retryAfter)
	}

	func cancelAndRemoveTasksWithHost(_ host: String) {

		cancelAndRemoveTasksWithHost(host, in: tasksInProgress)
		cancelAndRemoveTasksWithHost(host, in: tasksPending)
	}

	func cancelAndRemoveTasksWithHost(_ host: String, in tasks: Set<URLSessionTask>) {

		let lowercaseHost = host.lowercased()

		let tasksToRemove = tasks.filter { task in
			if let taskHost = task.lowercaseHost, taskHost.contains(lowercaseHost) {
				return false
			}
			return true
		}

		for task in tasksToRemove {
			task.cancel()
		}
		for task in tasksToRemove {
			removeTask(task)
		}
	}

	func requestShouldBeDroppedDueToActive429(_ url: URL) -> Bool {

		guard let host = url.host() else {
			return false
		}
		guard let retryAfterMessage = retryAfterMessages[host] else {
			return false
		}

		if retryAfterMessage.resumeDate < Date() {
			retryAfterMessages[host] = nil
			return false
		}

		return true
	}

	// MARK: - 400-499 responses

	func requestShouldBeDroppedDueToPrevious400(_ url: URL) -> Bool {

		if urlsWith400s.contains(url) {
			return true
		}
		if let redirectedURL = cachedRedirect(for: url), urlsWith400s.contains(redirectedURL) {
			return true
		}

		return false
	}

	// MARK: - Filtering URLs

	static private let lastOpenRSSOrgFeedRefreshKey = "lastOpenRSSOrgFeedRefresh"
	static private var lastOpenRSSOrgFeedRefresh: Date {
		get {
			UserDefaults.standard.value(forKey: lastOpenRSSOrgFeedRefreshKey) as? Date ?? Date.distantPast
		}
		set {
			UserDefaults.standard.setValue(newValue, forKey: lastOpenRSSOrgFeedRefreshKey)
		}
	}

	static private var canDownloadFromOpenRSSOrg: Bool {
		let okayToDownloadDate = lastOpenRSSOrgFeedRefresh + TimeInterval(60 * 60 * 10) // 10 minutes (arbitrary)
		return Date() > okayToDownloadDate
	}

	static func filteredURLs(_ urls: Set<URL>) -> Set<URL> {

		// Possibly remove some openrss.org URLs.
		// Can be extended later if necessary.

		if canDownloadFromOpenRSSOrg {
			// Allow only one feed from openrss.org per refresh session
			lastOpenRSSOrgFeedRefresh = Date()
			return urls.byRemovingAllButOneRandomOpenRSSOrgURL()
		}

		return urls.byRemovingOpenRSSOrgURLs()
	}
}

extension URLSessionTask {

	var lowercaseHost: String? {
		guard let request = currentRequest ?? originalRequest else {
			return nil
		}
		return request.url?.host()?.lowercased()
	}
}

// MARK: - DownloadInfo

private final class DownloadInfo {
	
	let url: URL
	let data = NSMutableData()
	var urlResponse: URLResponse?

	init(_ url: URL) {

		self.url = url
	}
	
	func addData(_ d: Data) {
		
		data.append(d)
	}
}
