//
//  DownloadSession.swift
//  RSWeb
//
//  Created by Brent Simmons on 3/12/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Create a DownloadSessionDelegate, then create a DownloadSession.
// To download things: call downloadObjects, with a set of represented objects, to download things. DownloadSession will call the various delegate methods.

public protocol DownloadSessionDelegate {

	func downloadSession(_ downloadSession: DownloadSession, requestForRepresentedObject: AnyObject) -> URLRequest?
	func downloadSession(_ downloadSession: DownloadSession, downloadDidCompleteForRepresentedObject: AnyObject, response: URLResponse?, data: Data, error: NSError?, completion: @escaping () -> Void)
	func downloadSession(_ downloadSession: DownloadSession, shouldContinueAfterReceivingData: Data, representedObject: AnyObject) -> Bool
	func downloadSession(_ downloadSession: DownloadSession, didReceiveUnexpectedResponse: URLResponse, representedObject: AnyObject)
	func downloadSession(_ downloadSession: DownloadSession, didReceiveNotModifiedResponse: URLResponse, representedObject: AnyObject)
	func downloadSession(_ downloadSession: DownloadSession, didDiscardDuplicateRepresentedObject: AnyObject)
	func downloadSessionDidCompleteDownloadObjects(_ downloadSession: DownloadSession)
	
}

@objc public final class DownloadSession: NSObject {
	
	private var urlSession: URLSession!
	private var tasksInProgress = Set<URLSessionTask>()
	private var tasksPending = Set<URLSessionTask>()
	private var taskIdentifierToInfoDictionary = [Int: DownloadInfo]()
	private let representedObjects = NSMutableSet()
	private let delegate: DownloadSessionDelegate
	private var redirectCache = [String: String]()
	private var queue = [AnyObject]()
	
	public init(delegate: DownloadSessionDelegate) {
		
		self.delegate = delegate

		super.init()
		
		let sessionConfiguration = URLSessionConfiguration.default
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

	public func downloadObjects(_ objects: NSSet) {
		for oneObject in objects {
			if !representedObjects.contains(oneObject) {
				representedObjects.add(oneObject)
				addDataTask(oneObject as AnyObject)
			} else {
				delegate.downloadSession(self, didDiscardDuplicateRepresentedObject: oneObject as AnyObject)
			}
		}
	}
}

// MARK: - URLSessionTaskDelegate

extension DownloadSession: URLSessionTaskDelegate {

	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		tasksInProgress.remove(task)
		
		guard let info = infoForTask(task) else {
			return
		}
		
		info.error = error

		delegate.downloadSession(self, downloadDidCompleteForRepresentedObject: info.representedObject, response: info.urlResponse, data: info.data as Data, error: error as NSError?) {
			self.removeTask(task)
		}
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
		
		tasksInProgress.insert(dataTask)
		tasksPending.remove(dataTask)
		
		if let info = infoForTask(dataTask) {
			info.urlResponse = response
		}

		if response.forcedStatusCode == 304 {

			if let representedObject = infoForTask(dataTask)?.representedObject {
				delegate.downloadSession(self, didReceiveNotModifiedResponse: response, representedObject: representedObject)
			}

			completionHandler(.cancel)
			removeTask(dataTask)

			return
		}

		if !response.statusIsOK {

			if let representedObject = infoForTask(dataTask)?.representedObject {
				delegate.downloadSession(self, didReceiveUnexpectedResponse: response, representedObject: representedObject)
			}

			completionHandler(.cancel)
			removeTask(dataTask)

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

		if !delegate.downloadSession(self, shouldContinueAfterReceivingData: info.data as Data, representedObject: info.representedObject) {
			
			info.canceled = true
			dataTask.cancel()
			removeTask(dataTask)
		}
	}
}

// MARK: - Private

private extension DownloadSession {

	func addDataTask(_ representedObject: AnyObject) {
		guard tasksPending.count < 500 else {
			queue.insert(representedObject, at: 0)
			return
		}
		
		guard let request = delegate.downloadSession(self, requestForRepresentedObject: representedObject) else {
			return
		}

		var requestToUse = request
		
		// If received permanent redirect earlier, use that URL.
		
		if let urlString = request.url?.absoluteString, let redirectedURLString = cachedRedirectForURLString(urlString) {
			if let redirectedURL = URL(string: redirectedURLString) {
				requestToUse.url = redirectedURL
			}
		}
		
		let task = urlSession.dataTask(with: requestToUse)

		let info = DownloadInfo(representedObject, urlRequest: requestToUse)
		taskIdentifierToInfoDictionary[task.taskIdentifier] = info

		tasksPending.insert(task)
		task.resume()
	}
	
	func addDataTaskFromQueueIfNecessary() {
		guard tasksPending.count < 500, let representedObject = queue.popLast() else { return }
		addDataTask(representedObject)
	}

	func infoForTask(_ task: URLSessionTask) -> DownloadInfo? {
		return taskIdentifierToInfoDictionary[task.taskIdentifier]
	}

	func removeTask(_ task: URLSessionTask) {
		tasksInProgress.remove(task)
		tasksPending.remove(task)
		taskIdentifierToInfoDictionary[task.taskIdentifier] = nil

		addDataTaskFromQueueIfNecessary()
		
		if tasksInProgress.count + tasksPending.count < 1 {
			representedObjects.removeAllObjects()
			delegate.downloadSessionDidCompleteDownloadObjects(self)
		}
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
}

// MARK: - DownloadInfo

private final class DownloadInfo {
	
	let representedObject: AnyObject
	let urlRequest: URLRequest
	let data = NSMutableData()
	var error: Error?
	var urlResponse: URLResponse?
	var canceled = false
	
	var statusCode: Int {
		return urlResponse?.forcedStatusCode ?? 0
	}
	
	init(_ representedObject: AnyObject, urlRequest: URLRequest) {
		
		self.representedObject = representedObject
		self.urlRequest = urlRequest
	}
	
	func addData(_ d: Data) {
		
		data.append(d)
	}
}

