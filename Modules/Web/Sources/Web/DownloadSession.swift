//
//  DownloadSession.swift
//  RSWeb
//
//  Created by Brent Simmons on 3/12/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os

// To download things: call `download` with a set of identifiers (String). Redirects are followed automatically.

public protocol DownloadSessionDelegate: AnyObject {

	// DownloadSession will add User-Agent header to request returned by delegate
	@MainActor func downloadSession(_ downloadSession: DownloadSession, requestForIdentifier: String) -> URLRequest?

	@MainActor func downloadSession(_ downloadSession: DownloadSession, downloadDidCompleteForIdentifier: String, response: URLResponse?, data: Data?, error: Error?)

	@MainActor func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData: Data, identifier: String) -> Bool

	@MainActor func downloadSession(_ downloadSession: DownloadSession, didReceiveUnexpectedResponse: URLResponse, identifier: String)

	@MainActor func downloadSession(_ downloadSession: DownloadSession, didReceiveNotModifiedResponse: URLResponse, identifier: String)

	@MainActor func downloadSession(_ downloadSession: DownloadSession, didDiscardDuplicateIdentifier: String)

	@MainActor func downloadSessionDidComplete(_ downloadSession: DownloadSession)
}

@MainActor @objc public final class DownloadSession: NSObject {

	public weak var delegate: DownloadSessionDelegate?
	public var downloadProgress = DownloadProgress(numberOfTasks: 0)

	private var urlSession: URLSession!
	private var tasksInProgress = Set<URLSessionTask>()
	private var tasksPending = Set<URLSessionTask>()
	private var taskIdentifierToInfoDictionary = [Int: DownloadInfo]()
	private var allIdentifiers = Set<String>()
	private var redirectCache = [String: String]()
	private var queue = [String]()

	override public init() {
		super.init()

		let sessionConfiguration = URLSessionConfiguration.default
		sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
		sessionConfiguration.timeoutIntervalForRequest = 15.0
		sessionConfiguration.httpShouldSetCookies = false
		sessionConfiguration.httpCookieAcceptPolicy = .never
		sessionConfiguration.httpMaximumConnectionsPerHost = 1
		sessionConfiguration.httpCookieStorage = nil
		sessionConfiguration.urlCache = nil
		sessionConfiguration.httpAdditionalHeaders = UserAgent.headers

		self.urlSession = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: OperationQueue.main)
	}

	deinit {

		urlSession.invalidateAndCancel()
	}

	// MARK: - API

	public func cancelAll() async {

		downloadProgress.clear()

		let (dataTasks, uploadTasks, downloadTasks) = await urlSession.tasks

		for dataTask in dataTasks {
			dataTask.cancel()
		}
		for uploadTask in uploadTasks {
			uploadTask.cancel()
		}
		for downloadTask in downloadTasks {
			downloadTask.cancel()
		}
	}

	public func download(_ identifiers: Set<String>) {

		for identifier in identifiers {
			if !allIdentifiers.contains(identifier) {
				allIdentifiers.insert(identifier)
				addDataTask(identifier)
			} else {
				delegate?.downloadSession(self, didDiscardDuplicateIdentifier: identifier)
			}
		}
	}
}

// MARK: - URLSessionTaskDelegate

extension DownloadSession: URLSessionTaskDelegate {

	nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

		MainActor.assumeIsolated {
			guard let info = infoForTask(task) else {
				assertionFailure("Missing info for task in DownloadSession didCompleteWithError")
				return
			}

			if let response = info.urlResponse, response.statusIsOK {
				delegate?.downloadSession(self, downloadDidCompleteForIdentifier: info.identifier, response: info.urlResponse, data: info.data, error: error)
			}
			
			removeTask(task)
		}
	}

	nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {

		MainActor.assumeIsolated {
			if response.statusCode == HTTPResponseCode.redirectTemporary || response.statusCode == HTTPResponseCode.redirectVeryTemporary {
				if let oldURLString = task.originalRequest?.url?.absoluteString, let newURLString = request.url?.absoluteString {
					cacheRedirect(oldURLString, newURLString)
				}
			}

			completionHandler(request)
		}
	}
}

// MARK: - URLSessionDataDelegate

extension DownloadSession: URLSessionDataDelegate {

	nonisolated public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

		MainActor.assumeIsolated {

			tasksInProgress.insert(dataTask)
			tasksPending.remove(dataTask)

			let info = infoForTask(dataTask)
			let identifier = info?.identifier
			info?.urlResponse = response

			if response.forcedStatusCode == HTTPResponseCode.notModified {

				if let identifier {
					delegate?.downloadSession(self, didReceiveNotModifiedResponse: response, identifier: identifier)
				}
				completionHandler(.allow)
				return
			}

			if !response.statusIsOK {

				if let identifier {
					delegate?.downloadSession(self, didReceiveUnexpectedResponse: response, identifier: identifier)
				}
				completionHandler(.cancel)
				return
			}

			addDataTaskFromQueueIfNecessary()

			completionHandler(.allow)
		}
	}

	nonisolated public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

		MainActor.assumeIsolated {
			
			guard let delegate, let info = infoForTask(dataTask) else {
				return
			}
			info.addData(data)
			
			if !delegate.downloadSession(self, shouldContinueAfterReceivingData: info.data!, identifier: info.identifier) {
				info.canceled = true
				dataTask.cancel()
				removeTask(dataTask)
			}
		}
	}
}

// MARK: - Private

private extension DownloadSession {

	func addDataTask(_ identifier: String) {

		downloadProgress.addTask()

		guard tasksPending.count < 500 else {
			queue.insert(identifier, at: 0)
			return
		}
		
		guard let request = delegate?.downloadSession(self, requestForIdentifier: identifier) else {
			downloadProgress.completeTask()
			return
		}

		var requestToUse = request
		
		// If received permanent redirect earlier, use that URL.
		
		if let urlString = request.url?.absoluteString, let redirectedURLString = cachedRedirectForURLString(urlString) {
			if let redirectedURL = URL(string: redirectedURLString) {
				requestToUse.url = redirectedURL
			}
		}
		
		requestToUse.httpShouldHandleCookies = false
		
		let task = urlSession.dataTask(with: requestToUse)

		let info = DownloadInfo(identifier, urlRequest: requestToUse)
		taskIdentifierToInfoDictionary[task.taskIdentifier] = info

		tasksPending.insert(task)
		task.resume()

		updateDownloadProgress()
	}
	
	func addDataTaskFromQueueIfNecessary() {

		guard tasksPending.count < 500, let identifier = queue.popLast() else {
			return
		}
		addDataTask(identifier)
	}

	func infoForTask(_ task: URLSessionTask) -> DownloadInfo? {

		return taskIdentifierToInfoDictionary[task.taskIdentifier]
	}

	func removeTask(_ task: URLSessionTask) {

		tasksInProgress.remove(task)
		tasksPending.remove(task)
		taskIdentifierToInfoDictionary[task.taskIdentifier] = nil

		addDataTaskFromQueueIfNecessary()

		downloadProgress.completeTask()
		updateDownloadProgress()

		if tasksInProgress.count + tasksPending.count + queue.count < 1 { // Finished?
			allIdentifiers = Set<String>()
			delegate?.downloadSessionDidComplete(self)
			downloadProgress.clear()
		}
	}
	
	func updateDownloadProgress() {
		
//		downloadProgress.numberRemaining = tasksInProgress.count + tasksPending.count + queue.count
	}

	static let badRedirectStrings = ["solutionip", "lodgenet", "monzoon", "landingpage", "btopenzone", "register", "login", "authentic"]

	func urlStringIsDisallowedRedirect(_ urlString: String) -> Bool {

		// Hotels and similar often do permanent redirects. We can catch some of those.
		
		let s = urlString.lowercased()

		for oneBadString in Self.badRedirectStrings {
			if s.contains(oneBadString) {
				return true
			}
		}
		
		return false
	}
	
	func cacheRedirect(_ oldURLString: String, _ newURLString: String) {

		if urlStringIsDisallowedRedirect(newURLString) {
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
}

// MARK: - DownloadInfo

private final class DownloadInfo {
	
	let identifier: String
	let urlRequest: URLRequest
	var data: Data?
	var error: Error?
	var urlResponse: URLResponse?
	var canceled = false
	
	var statusCode: Int {
		return urlResponse?.forcedStatusCode ?? 0
	}
	
	init(_ identifier: String, urlRequest: URLRequest) {

		self.identifier = identifier
		self.urlRequest = urlRequest
	}
	
	func addData(_ d: Data) {

		if data == nil {
			data = Data()
		}
		data!.append(d)
	}
}
