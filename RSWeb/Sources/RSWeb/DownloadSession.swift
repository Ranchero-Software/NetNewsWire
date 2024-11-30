//
//  DownloadSession.swift
//  RSWeb
//
//  Created by Brent Simmons on 3/12/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Create a DownloadSessionDelegate, then create a DownloadSession.
// To download things: call download with a set of URLs. DownloadSession will call the various delegate methods.

public protocol DownloadSessionDelegate {

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
	private var redirectCache = [String: String]()
	private var queue = [URL]()
	private var retryAfterMessages = [String: HTTPResponse429]()

	public init(delegate: DownloadSessionDelegate) {
		
		self.delegate = delegate

		super.init()
		
		let sessionConfiguration = URLSessionConfiguration.default
		sessionConfiguration.requestCachePolicy = .useProtocolCachePolicy
		sessionConfiguration.timeoutIntervalForRequest = 15.0
		sessionConfiguration.httpShouldSetCookies = false
		sessionConfiguration.httpCookieAcceptPolicy = .never
		sessionConfiguration.httpMaximumConnectionsPerHost = 1
		sessionConfiguration.httpCookieStorage = nil

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

		for url in urls.subtracting(urlsInSession) {
			addDataTask(url)
		}
		urlsInSession.formUnion(urls)
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

	public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
		
		if response.statusCode == 301 || response.statusCode == 308 {
			if let oldURLString = task.originalRequest?.url?.absoluteString, let newURLString = request.url?.absoluteString {
				cacheRedirect(oldURLString, newURLString)
			}
		}
		
		completionHandler(request)
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
		
		if let info = infoForTask(dataTask) {
			info.urlResponse = response
		}

		if !response.statusIsOK {

			completionHandler(.cancel)
			removeTask(dataTask)

			if response.forcedStatusCode == HTTPResponseCode.tooManyRequests {
				handle429Response(dataTask, response)
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

		var urlToUse = url

		// If received permanent redirect earlier, use that URL.
		let urlString = url.absoluteString
		if let redirectedURLString = cachedRedirectForURLString(urlString) {
			if let redirectedURL = URL(string: redirectedURLString) {
				urlToUse = redirectedURL
			}
		}

		if requestShouldBeDroppedDueToActive429(urlToUse) {
			return
		}

		let task = urlSession.dataTask(with: urlToUse)

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

	func cacheRedirect(_ oldURLString: String, _ newURLString: String) {
		if urlStringIsBlackListedRedirect(newURLString) {
			return
		}
		redirectCache[oldURLString] = newURLString
	}

	func cachedRedirectForURLString(_ urlString: String) -> String? {

		// Follow chains of redirects, but avoid loops.

		var urlStrings = Set<String>()
		urlStrings.insert(urlString)

		var currentString = urlString

		while(true) {

			if let oneRedirectString = redirectCache[currentString] {

				if urlStrings.contains(oneRedirectString) {
					// Cycle. Bail.
					return nil
				}
				urlStrings.insert(oneRedirectString)
				currentString = oneRedirectString
			}

			else {
				break
			}
		}

		return currentString == urlString ? nil : currentString
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
		guard let retryAfterSeconds = Int(retryAfterValue), retryAfterSeconds > 0 else {
			return nil
		}

		return HTTPResponse429(url: url, retryAfterSeconds: retryAfterSeconds)
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
