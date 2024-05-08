//
//  Transport.swift
//  RSWeb
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//
// Inspired by: http://robnapier.net/a-mockery-of-protocols

import Foundation

public enum TransportError: LocalizedError {
	case noData
    case noURL
	case suspended
	case httpError(status: Int)
	
	public var errorDescription: String? {
		switch self {
		case .httpError(let status):
			switch status {
			case 400:
				return NSLocalizedString("Bad Request", comment: "Bad Request")
			case 401:
				return NSLocalizedString("Unauthorized", comment: "Unauthorized")
			case 402:
				return NSLocalizedString("Payment Required", comment: "Payment Required")
			case 403:
				return NSLocalizedString("Forbidden", comment: "Forbidden")
			case 404:
				return NSLocalizedString("Not Found", comment: "Not Found")
			case 405:
				return NSLocalizedString("Method Not Allowed", comment: "Method Not Allowed")
			case 406:
				return NSLocalizedString("Not Acceptable", comment: "Not Acceptable")
			case 407:
				return NSLocalizedString("Proxy Authentication Required", comment: "Proxy Authentication Required")
			case 408:
				return NSLocalizedString("Request Timeout", comment: "Request Timeout")
			case 409:
				return NSLocalizedString("Conflict", comment: "Conflict")
			case 410:
				return NSLocalizedString("Gone", comment: "Gone")
			case 411:
				return NSLocalizedString("Length Required", comment: "Length Required")
			case 412:
				return NSLocalizedString("Precondition Failed", comment: "Precondition Failed")
			case 413:
				return NSLocalizedString("Payload Too Large", comment: "Payload Too Large")
			case 414:
				return NSLocalizedString("Request-URI Too Long", comment: "Request-URI Too Long")
			case 415:
				return NSLocalizedString("Unsupported Media Type", comment: "Unsupported Media Type")
			case 416:
				return NSLocalizedString("Requested Range Not Satisfiable", comment: "Requested Range Not Satisfiable")
			case 417:
				return NSLocalizedString("Expectation Failed", comment: "Expectation Failed")
			case 418:
				return NSLocalizedString("I'm a teapot", comment: "I'm a teapot")
			case 421:
				return NSLocalizedString("Misdirected Request", comment: "Misdirected Request")
			case 422:
				return NSLocalizedString("Unprocessable Entity", comment: "Unprocessable Entity")
			case 423:
				return NSLocalizedString("Locked", comment: "Locked")
			case 424:
				return NSLocalizedString("Failed Dependency", comment: "Failed Dependency")
			case 426:
				return NSLocalizedString("Upgrade Required", comment: "Upgrade Required")
			case 428:
				return NSLocalizedString("Precondition Required", comment: "Precondition Required")
			case 429:
				return NSLocalizedString("Too Many Requests", comment: "Too Many Requests")
			case 431:
				return NSLocalizedString("Request Header Fields Too Large", comment: "Request Header Fields Too Large")
			case 444:
				return NSLocalizedString("Connection Closed Without Response", comment: "Connection Closed Without Response")
			case 451:
				return NSLocalizedString("Unavailable For Legal Reasons", comment: "Unavailable For Legal Reasons")
			case 499:
				return NSLocalizedString("Client Closed Request", comment: "Client Closed Request")
			case 500:
				return NSLocalizedString("Internal Server Error", comment: "Internal Server Error")
			case 501:
				return NSLocalizedString("Not Implemented", comment: "Not Implemented")
			case 502:
				return NSLocalizedString("Bad Gateway", comment: "Bad Gateway")
			case 503:
				return NSLocalizedString("Service Unavailable", comment: "Service Unavailable")
			case 504:
				return NSLocalizedString("Gateway Timeout", comment: "Gateway Timeout")
			case 505:
				return NSLocalizedString("HTTP Version Not Supported", comment: "HTTP Version Not Supported")
			case 506:
				return NSLocalizedString("Variant Also Negotiates", comment: "Variant Also Negotiates")
			case 507:
				return NSLocalizedString("Insufficient Storage", comment: "Insufficient Storage")
			case 508:
				return NSLocalizedString("Loop Detected", comment: "Loop Detected")
			case 510:
				return NSLocalizedString("Not Extended", comment: "Not Extended")
			case 511:
				return NSLocalizedString("Network Authentication Required", comment: "Network Authentication Required")
			case 599:
				return NSLocalizedString("Network Connect Timeout Error", comment: "Network Connect Timeout Error")
			default:
				let msg = NSLocalizedString("HTTP Status: ", comment: "Unexpected error")
				return "\(msg) \(status)"
			}
		default:
			return NSLocalizedString("An unknown network error occurred.", comment: "Unknown error")
		}
	}
	
}

public protocol Transport: Sendable {
	
	/// Cancels all pending requests
	func cancelAll()
	
	/// Sends URLRequest and returns the HTTP headers and the data payload.
	@discardableResult
	func send(request: URLRequest) async throws -> (HTTPURLResponse, Data?)

	func send(request: URLRequest, completion: @escaping @Sendable (Result<(HTTPURLResponse, Data?), Error>) -> Void)

	/// Sends URLRequest that doesn't require any result information.
	func send(request: URLRequest, method: String) async throws

	func send(request: URLRequest, method: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void)

	/// Sends URLRequest with a data payload and returns the HTTP headers and the data payload.
	@discardableResult
	func send(request: URLRequest, method: String, payload: Data) async throws -> (HTTPURLResponse, Data?)

	func send(request: URLRequest, method: String, payload: Data, completion: @escaping @Sendable (Result<(HTTPURLResponse, Data?), Error>) -> Void)

}

extension URLSession: Transport {
	
	public func cancelAll() {
		getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
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
	}
	
	public func send(request: URLRequest) async throws -> (HTTPURLResponse, Data?) {

		try await withCheckedThrowingContinuation { continuation in
			self.send(request: request) { result in
				switch result {
				case .success(let (response, data)):
					continuation.resume(returning: (response, data))
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	public func send(request: URLRequest, completion: @escaping @Sendable (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
		let task = self.dataTask(with: request) { (data, response, error) in
			DispatchQueue.main.async {
				if let error = error {
					return completion(.failure(error))
				}

				guard let response = response as? HTTPURLResponse, let data = data else {
					return completion(.failure(TransportError.noData))
				}

				switch response.forcedStatusCode {
				case 200...399:
					completion(.success((response, data)))
				default:
					completion(.failure(TransportError.httpError(status: response.forcedStatusCode)))
				}
			}
		}
		task.resume()
	}

	public func send(request: URLRequest, method: String) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.send(request: request, method: method) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	public func send(request: URLRequest, method: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {

		var sendRequest = request
		sendRequest.httpMethod = method
		
		let task = self.dataTask(with: sendRequest) { (data, response, error) in
			DispatchQueue.main.async {
				if let error = error {
					return completion(.failure(error))
				}

				guard let response = response as? HTTPURLResponse else {
					return completion(.failure(TransportError.noData))
				}

				switch response.forcedStatusCode {
				case 200...399:
					completion(.success(()))
				default:
					completion(.failure(TransportError.httpError(status: response.forcedStatusCode)))
				}
			}
		}
		task.resume()
	}
	
	public func send(request: URLRequest, method: String, payload: Data) async throws -> (HTTPURLResponse, Data?) {

		try await withCheckedThrowingContinuation { continuation in
			self.send(request: request, method: method, payload: payload) { result in
				switch result {
				case .success(let (response, data)):
					continuation.resume(returning: (response, data))
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	public func send(request: URLRequest, method: String, payload: Data, completion: @escaping @Sendable (Result<(HTTPURLResponse, Data?), Error>) -> Void) {
		
		var sendRequest = request
		sendRequest.httpMethod = method
		
		let task = self.uploadTask(with: sendRequest, from: payload) { (data, response, error) in
			DispatchQueue.main.async {
				if let error = error {
					return completion(.failure(error))
				}

				guard let response = response as? HTTPURLResponse, let data = data else {
					return completion(.failure(TransportError.noData))
				}

				switch response.forcedStatusCode {
				case 200...399:
					completion(.success((response, data)))
				default:
					completion(.failure(TransportError.httpError(status: response.forcedStatusCode)))
				}
				
			}
		}
		task.resume()
	}
	
	public static func webserviceTransport() -> Transport {
	
		let sessionConfiguration = URLSessionConfiguration.default
		sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
		sessionConfiguration.timeoutIntervalForRequest = 60.0
		sessionConfiguration.httpShouldSetCookies = false
		sessionConfiguration.httpCookieAcceptPolicy = .never
		sessionConfiguration.httpMaximumConnectionsPerHost = 2
		sessionConfiguration.httpCookieStorage = nil
		sessionConfiguration.urlCache = nil
		sessionConfiguration.httpAdditionalHeaders = UserAgent.headers

		return URLSession(configuration: sessionConfiguration)
	}
}
